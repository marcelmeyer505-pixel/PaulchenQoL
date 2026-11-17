import os
import sqlite3
import sys
from contextlib import closing
from ctypes import POINTER, Structure, WinDLL, byref, c_size_t, c_void_p, create_unicode_buffer, get_last_error, sizeof
from ctypes.wintypes import BOOL, DWORD, HANDLE, LONG, LPCWSTR, LPWSTR, WCHAR
from pathlib import Path
from threading import Event, Thread
from time import sleep

from CritFont import Publisher, prepare_bank
from ImportCritRecords import combat_logs, game_directory, parse_line, write_records


def open_database(path):
    db = sqlite3.connect(path)
    db.executescript("""
        CREATE TABLE IF NOT EXISTS logs (
            path TEXT PRIMARY KEY, identity TEXT, position INTEGER, advanced INTEGER
        );
        CREATE TABLE IF NOT EXISTS records (
            guid TEXT, spell_id INTEGER, damage INTEGER, spell TEXT, player TEXT,
            seen INTEGER, PRIMARY KEY (guid, spell_id)
        );
    """)
    return db


def scan_log(db, path, stop):
    with path.open("rb") as source:
        stat = os.fstat(source.fileno())
        identity = f"{stat.st_dev}:{stat.st_ino}"
        state = db.execute("SELECT identity, position, advanced FROM logs WHERE path = ?", (path.name,)).fetchone()
        position, advanced = 0, None
        if state and state[0] == identity and state[1] <= stat.st_size:
            position, advanced = state[1:]
        if position == stat.st_size:
            return False

        source.seek(position)
        start = position
        records = {}
        while position < stat.st_size and (stop is None or not stop.is_set()):
            line = source.readline()
            if not line.endswith(b"\n"):
                break
            position += len(line)
            advanced, hit = parse_line(line.decode("utf-8", errors="replace"), advanced)
            if hit:
                guid, spell_id, damage, spell, player = hit
                key = guid, spell_id
                if key not in records or damage > records[key][0]:
                    records[key] = damage, spell, player

    if position == start:
        return False

    # Commit the new file position with its records, so a restart can resume safely.
    with db:
        update = db.executemany("""
            INSERT INTO records VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(guid, spell_id) DO UPDATE SET
                damage = excluded.damage, spell = excluded.spell, player = excluded.player,
                seen = excluded.seen
            WHERE excluded.damage > records.damage
        """, ((*key, *record, stat.st_mtime_ns) for key, record in records.items()))
        db.execute("REPLACE INTO logs VALUES (?, ?, ?, ?)", (path.name, identity, position, advanced))
    return update.rowcount > 0


def watch(addon, stop):
    with closing(open_database(addon / "CritLive.sqlite3")) as db:
        publisher = Publisher(addon) if (addon / "CritFontBase.ttf").is_file() else None
        needs_export = True
        while True:
            final_scan = stop.is_set()
            for path in sorted(combat_logs(addon)):
                try:
                    needs_export = scan_log(db, path, None if final_scan else stop) or needs_export
                except (OSError, sqlite3.Error):
                    continue  # The client may still be closing or rotating this file.
            if needs_export:
                exported = {}
                for guid, spell_id, damage, spell in db.execute("SELECT guid, spell_id, damage, spell FROM records"):
                    exported.setdefault(guid, {})[spell_id] = damage, spell
                try:
                    if exported:
                        write_records(addon / "CritRecordsData.lua", exported)
                    if publisher:
                        publisher.update(exported)
                    needs_export = False
                except OSError:
                    pass  # Retry the snapshot if WoW was loading it during this write.
            if publisher:
                try:
                    publisher.tick()
                except OSError:
                    pass  # A subsequent slot is available if WoW has opened this one.
            if final_scan:
                break
            stop.wait(1)


class ProcessEntry(Structure):
    _fields_ = [
        ("dwSize", DWORD),
        ("cntUsage", DWORD),
        ("th32ProcessID", DWORD),
        ("th32DefaultHeapID", c_size_t),
        ("th32ModuleID", DWORD),
        ("cntThreads", DWORD),
        ("th32ParentProcessID", DWORD),
        ("pcPriClassBase", LONG),
        ("dwFlags", DWORD),
        ("szExeFile", WCHAR * 260),
    ]


def windows_api():
    kernel = WinDLL("kernel32", use_last_error=True)
    kernel.CreateToolhelp32Snapshot.argtypes = (DWORD, DWORD)
    kernel.CreateToolhelp32Snapshot.restype = HANDLE
    kernel.Process32FirstW.argtypes = kernel.Process32NextW.argtypes = (HANDLE, POINTER(ProcessEntry))
    kernel.Process32FirstW.restype = kernel.Process32NextW.restype = BOOL
    kernel.QueryFullProcessImageNameW.argtypes = (HANDLE, DWORD, LPWSTR, POINTER(DWORD))
    kernel.QueryFullProcessImageNameW.restype = BOOL
    kernel.CreateMutexW.argtypes = (c_void_p, BOOL, LPCWSTR)
    kernel.CreateMutexW.restype = HANDLE
    kernel.OpenProcess.argtypes = (DWORD, BOOL, DWORD)
    kernel.OpenProcess.restype = HANDLE
    kernel.WaitForSingleObject.argtypes = (HANDLE, DWORD)
    kernel.WaitForSingleObject.restype = DWORD
    kernel.CloseHandle.argtypes = (HANDLE,)
    kernel.CloseHandle.restype = BOOL
    return kernel


def find_game(kernel, executable):
    snapshot = kernel.CreateToolhelp32Snapshot(0x00000002, 0)  # TH32CS_SNAPPROCESS
    if snapshot == c_void_p(-1).value:
        return None
    try:
        entry = ProcessEntry()
        entry.dwSize = sizeof(entry)
        found = kernel.Process32FirstW(snapshot, byref(entry))
        while found:
            if entry.szExeFile.casefold() == executable.name.casefold():
                # Query the executable path and wait for exit. No memory access is needed.
                game = kernel.OpenProcess(0x00100000 | 0x1000, False, entry.th32ProcessID)
                if game:
                    path = create_unicode_buffer(32768)
                    size = DWORD(len(path))
                    if kernel.QueryFullProcessImageNameW(game, 0, path, byref(size)):
                        if os.path.normcase(path.value) == os.path.normcase(str(executable)):
                            return game
                    kernel.CloseHandle(game)
            found = kernel.Process32NextW(snapshot, byref(entry))
    finally:
        kernel.CloseHandle(snapshot)
    return None


def single_instance(kernel, name):
    lock = kernel.CreateMutexW(None, False, name)
    already_running = get_last_error() == 183
    if lock and already_running:
        kernel.CloseHandle(lock)
        return None
    return lock


def watch_game(addon, kernel, game):
    lock = single_instance(kernel, r"Local\DetailsCombatTimelineCritLive")
    if not lock:
        return
    try:
        stop = Event()

        def wait_for_exit():
            # WAIT_TIMEOUT keeps the monitor responsive to a stopped reader.
            while not stop.is_set() and kernel.WaitForSingleObject(game, 500) == 258:
                pass
            stop.set()

        monitor = Thread(target=wait_for_exit, daemon=True)
        monitor.start()
        try:
            watch(addon, stop)
        finally:
            stop.set()
            monitor.join()
    finally:
        kernel.CloseHandle(lock)


def main():
    addon = Path(__file__).resolve().parent
    executable = game_directory(addon) / "Wow.exe"
    kernel = windows_api()
    autostart = "--autostart" in sys.argv[1:]
    autostart_lock = single_instance(kernel, r"Local\DetailsCombatTimelineCritAutostart") if autostart else None
    if autostart and not autostart_lock:
        return
    try:
        if (addon / "CritFontBase.ttf").is_file() and not (addon / "CritFonts" / "s4095.ttf").is_file():
            prepare_bank(addon)
        while True:
            game = find_game(kernel, executable)
            if game:
                try:
                    watch_game(addon, kernel, game)
                except (OSError, sqlite3.Error):
                    if not autostart:
                        raise
                finally:
                    kernel.CloseHandle(game)
            if not autostart:
                return
            sleep(5)
    finally:
        if autostart_lock:
            kernel.CloseHandle(autostart_lock)


if __name__ == "__main__":
    main()
