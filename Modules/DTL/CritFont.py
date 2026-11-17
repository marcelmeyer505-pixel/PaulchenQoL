import struct
import time
import zlib
from pathlib import Path
from tempfile import NamedTemporaryFile
import os


SLOT_SECONDS = 30
SLOT_COUNT = 4096
PACKET_LIMIT = 512
MAX_DAMAGE = 1 << 48


def checksum(data):
    padded = data + b"\0" * (-len(data) % 4)
    return sum(number for (number,) in struct.iter_unpack(">I", padded)) & 0xFFFFFFFF


def search_fields(count, width):
    exponent = count.bit_length() - 1
    span = (1 << exponent) * width
    return span, exponent, count * width - span


def make_cmap(packet):
    # Four mapped ranges and the required terminal range in cmap format 4.
    last = 0xE000 + len(packet) - 1
    subtable = struct.pack(">7H", 4, 56 + 2 * len(packet), 0, 10, *search_fields(5, 2))
    subtable += struct.pack(">6H", 33, 34, 126, last, 0xFFFF, 0)
    subtable += struct.pack(">5H", 33, 34, 126, 0xE000, 0xFFFF)
    subtable += struct.pack(">5h", 1 - 33, 256 - 34, 17 - 126, 0, 1)
    subtable += struct.pack(">5H", 0, 0, 0, 4, 0)
    subtable += struct.pack(f">{len(packet)}H", *(byte + 1 for byte in packet))
    return struct.pack(">HHHHIHHI", 0, 2, 0, 3, 20, 3, 1, 20) + subtable


def make_name(epoch):
    family = f"DTLCritData{epoch}"
    values = ((1, family), (2, "Regular"), (3, family), (4, family), (6, family))
    names = bytearray(struct.pack(">HHH", 0, len(values), 6 + 12 * len(values)))
    text = bytearray()
    for name_id, value in values:
        encoded = value.encode("utf-16-be")
        names.extend(struct.pack(">6H", 3, 1, 0x0409, name_id, len(encoded), len(text)))
        text.extend(encoded)
    return names + text


def make_font(template, packet, epoch):
    count = struct.unpack_from(">H", template, 4)[0]
    offset = 12 + 16 * count
    directory = bytearray(template[:12])
    tables = bytearray()
    for tag, _, start, length in struct.iter_unpack(">4sIII", template[12:offset]):
        data = template[start:start + length]
        if tag == b"cmap":
            data = make_cmap(packet)
        if tag == b"name":
            data = make_name(epoch)
        if tag == b"head":
            adjustment_offset = offset + len(tables) + 8
            data = data[:8] + b"\0" * 4 + data[12:]
        directory.extend(struct.pack(">4sIII", tag, checksum(data), offset + len(tables), len(data)))
        tables.extend(data + b"\0" * (-len(data) % 4))
    result = directory + tables
    struct.pack_into(">I", result, adjustment_offset, (0xB1B0AFBA - checksum(result)) & 0xFFFFFFFF)
    return result


def slot_path(directory, epoch):
    return directory / f"s{epoch % SLOT_COUNT:04d}.ttf"


def prepare_bank(addon):
    directory = addon / "CritFonts"
    directory.mkdir(exist_ok=True)
    template = (addon / "CritFontBase.ttf").read_bytes()
    for slot in range(SLOT_COUNT):
        path = slot_path(directory, slot)
        seed = directory / f"base{slot // 512:02d}.ttf"
        if not seed.exists():
            seed.write_bytes(template)
        try:
            os.link(seed, path)
        except FileExistsError:
            continue


def record_chunks(records):
    chunks = []
    for guid, character in sorted(records.items()):
        name = guid.encode("ascii")
        per_packet = (PACKET_LIMIT - 15 - len(name)) // 10
        hits = [(spell_id, damage) for spell_id, (damage, _) in sorted(character.items()) if damage < MAX_DAMAGE]
        for index in range(0, len(hits), per_packet):
            batch = hits[index:index + per_packet]
            body = name + b"".join(struct.pack(">I", spell) + damage.to_bytes(6, "big") for spell, damage in batch)
            chunks.append((len(name), len(batch), body))
    return chunks


class Publisher:
    def __init__(self, addon):
        self.directory = addon / "CritFonts"
        self.template = (addon / "CritFontBase.ttf").read_bytes()
        self.chunks = []
        self.published = set()

    def update(self, records):
        self.chunks = record_chunks(records)
        self.published.clear()

    def tick(self):
        if not self.chunks:
            return
        epoch = int(time.time()) // SLOT_SECONDS
        self.published.intersection_update({epoch, epoch + 1, epoch + 2})
        for target in range(epoch, epoch + 3):
            if target in self.published:
                continue
            guid_size, count, body = self.chunks[target % len(self.chunks)]
            packet = struct.pack(">4sIIBH", b"DTL1", target, zlib.adler32(body), guid_size, count) + body
            destination = slot_path(self.directory, target)
            temporary = None
            try:
                with NamedTemporaryFile(mode="wb", dir=self.directory, delete=False) as output:
                    temporary = Path(output.name)
                    output.write(make_font(self.template, packet, target))
                os.replace(temporary, destination)
                self.published.add(target)
            finally:
                if temporary is not None:
                    temporary.unlink(missing_ok=True)
