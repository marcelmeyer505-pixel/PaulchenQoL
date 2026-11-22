-- Factual item/quest release memberships. See README: Content availability data.
-- Generated with work/paulchen_content_build.py from installed Classic/Forever data.
local _, suite = ...
local app = suite.upgrades
if not app then return end
local content = { items = {}, quests = {} }
app.content = content
local function register(group, ids)
    for id in ids:gmatch("%d+") do
        id = tonumber(id)
        local entry = content.items[id] or {}
        entry[group], content.items[id] = true, entry
    end
end
register("mc", [[
11382 16665 16795 16796 16797 16798 16799 16800 16801 16802 16803 16804 16805 16806 16807 16808 16809 16810 16811 16812 16813 16814
16815 16816 16817 16819 16820 16821 16822 16823 16824 16825 16826 16827 16828 16829 16830 16831 16833 16834 16835 16836 16837 16838
16839 16840 16841 16842 16843 16844 16845 16846 16847 16848 16849 16850 16851 16852 16853 16854 16855 16856 16857 16858 16859 16860
16861 16862 16863 16864 16865 16866 16867 16868 16901 16909 16915 16922 16930 16938 16946 16954 16962 17010 17011 17012 17063 17065
17066 17069 17071 17072 17073 17074 17076 17077 17082 17102 17103 17104 17105 17106 17107 17109 17110 17203 17204 17333 18203 18252
18257 18259 18260 18264 18265 18290 18291 18292 18563 18564 18646 18703 18803 18805 18806 18808 18809 18810 18811 18812 18814 18815
18816 18817 18820 18821 18822 18823 18824 18829 18832 18842 18861 18870 18872 18875 18878 18879 19017 19019 19136 19137 19138 19139
19140 19142 19143 19144 19145 19146 19147 21371 22687 22695 22698 22705 22754
]])
register("onyxia", [[
11938 15410 16900 16908 16914 16921 16929 16939 16947 16955 16963 17064 17067 17068 17075 17078 17962 17963 17964 17965 17966 17969
18205 18403 18404 18406 18422 18423 18705 18813
]])
register("bwl", [[
11938 16818 16832 16897 16898 16899 16902 16903 16904 16905 16906 16907 16910 16911 16912 16913 16916 16917 16918 16919 16920 16923
16924 16925 16926 16927 16928 16931 16932 16933 16934 16935 16936 16937 16940 16941 16942 16943 16944 16945 16948 16949 16950 16951
16952 16953 16956 16957 16958 16959 16960 16961 16964 16965 16966 17962 17963 17964 17965 17969 18562 19334 19335 19336 19337 19339
19340 19341 19342 19343 19344 19345 19346 19347 19348 19349 19350 19351 19352 19353 19354 19355 19356 19357 19358 19360 19361 19362
19363 19364 19365 19367 19368 19369 19370 19371 19372 19373 19374 19375 19376 19377 19378 19379 19380 19381 19382 19385 19386 19387
19388 19389 19390 19391 19392 19393 19394 19395 19396 19397 19398 19399 19400 19401 19402 19403 19405 19406 19407 19430 19431 19432
19433 19434 19435 19436 19437 19438 19439 20383 21517 21520 21521 21522 21523 21526 21527 21529 21530 21531 21532
]])
register("zg", [[
19698 19699 19700 19701 19702 19703 19704 19705 19706 19707 19708 19709 19710 19711 19712 19713 19714 19715 19716 19717 19718 19719
19720 19721 19722 19723 19724 19726 19727 19764 19765 19766 19767 19768 19769 19770 19771 19772 19773 19774 19776 19777 19778 19779
19780 19781 19782 19783 19784 19785 19786 19787 19788 19789 19790 19802 19813 19814 19815 19816 19817 19818 19819 19820 19821 19822
19823 19824 19825 19826 19827 19828 19829 19830 19831 19832 19833 19834 19835 19836 19838 19839 19840 19841 19842 19843 19845 19846
19848 19849 19852 19853 19854 19855 19856 19857 19859 19861 19862 19863 19864 19865 19866 19867 19869 19870 19871 19872 19873 19874
19875 19876 19877 19878 19884 19885 19886 19887 19888 19889 19890 19891 19892 19893 19894 19895 19896 19897 19898 19899 19900 19901
19902 19903 19904 19905 19906 19907 19908 19909 19910 19912 19913 19914 19915 19918 19919 19920 19921 19922 19923 19925 19927 19928
19929 19930 19939 19940 19941 19942 19944 19945 19946 19947 19948 19949 19950 19961 19962 19963 19964 19965 19967 19968 19975 19993
20000 20001 20011 20012 20013 20014 20031 20032 20033 20034 20038 20076 20077 20078 20079 20080 20081 20213 20215 20216 20217 20258
20259 20260 20261 20262 20263 20265 20266 20756 20757 22635 22637 22711 22712 22713 22714 22715 22716 22718 22720 22721 22722 22739
]])
register("aq20", [[
20858 20859 20860 20861 20862 20863 20864 20865 20866 20867 20868 20869 20870 20871 20872 20873 20884 20885 20886 20888 20889 20890
21156 21200 21205 21210 21214 21220 21279 21280 21281 21282 21283 21284 21285 21287 21288 21289 21290 21291 21292 21293 21294 21295
21296 21297 21298 21299 21300 21302 21303 21304 21306 21307 21392 21393 21394 21395 21396 21397 21398 21399 21400 21401 21402 21403
21404 21405 21406 21407 21408 21409 21410 21411 21412 21413 21414 21415 21416 21417 21418 21452 21455 21456 21457 21458 21459 21460
21461 21462 21463 21464 21466 21467 21468 21469 21470 21471 21472 21473 21474 21475 21476 21477 21478 21479 21480 21481 21482 21483
21484 21485 21488 21489 21490 21491 21492 21493 21494 21495 21496 21497 21498 21499 21500 21501 21502 21503 21504 21505 21506 21507
21715 21761 21800 21801 21802 21805 21806 21809 21810 22202 22203 22220
]])
register("aq40", [[
20726 20735 20926 20927 20928 20929 20930 20931 20932 20933 21126 21128 21134 21196 21197 21198 21199 21200 21201 21202 21203 21204
21205 21206 21207 21208 21209 21210 21218 21221 21232 21237 21242 21244 21268 21269 21272 21273 21275 21321 21323 21324 21329 21330
21331 21332 21333 21334 21335 21336 21337 21338 21343 21344 21345 21346 21347 21348 21349 21350 21351 21352 21353 21354 21355 21356
21357 21359 21360 21361 21362 21364 21365 21366 21367 21368 21370 21372 21373 21374 21375 21376 21387 21388 21389 21390 21391 21579
21581 21582 21583 21585 21586 21596 21597 21598 21599 21600 21601 21602 21603 21604 21605 21606 21607 21608 21609 21610 21611 21615
21616 21617 21618 21619 21620 21621 21622 21623 21624 21625 21626 21627 21635 21639 21645 21647 21648 21650 21651 21652 21663 21664
21665 21666 21667 21668 21669 21670 21671 21672 21673 21674 21675 21676 21677 21678 21679 21680 21681 21682 21683 21684 21685 21686
21687 21688 21689 21690 21691 21692 21693 21694 21695 21696 21697 21698 21699 21700 21701 21702 21703 21704 21705 21706 21707 21708
21709 21710 21712 21814 21836 21837 21838 21839 21856 21888 21889 21890 21891 22222 22396 22399 22402 22589 22630 22631 22632 22730
22731 22732 22734 23557 23558 23570
]])
register("naxx", [[
22349 22350 22351 22352 22353 22354 22355 22356 22357 22358 22359 22360 22361 22362 22363 22364 22365 22366 22367 22368 22369 22370
22371 22372 22373 22374 22375 22376 22416 22417 22418 22419 22420 22421 22422 22423 22424 22425 22426 22427 22428 22429 22430 22431
22436 22437 22438 22439 22440 22441 22442 22443 22464 22465 22466 22467 22468 22469 22470 22471 22476 22477 22478 22479 22480 22481
22482 22483 22488 22489 22490 22491 22492 22493 22494 22495 22496 22497 22498 22499 22500 22501 22502 22503 22504 22505 22506 22507
22508 22509 22510 22511 22512 22513 22514 22515 22516 22517 22518 22519 22520 22652 22654 22655 22658 22661 22662 22663 22664 22665
22666 22669 22670 22671 22682 22691 22699 22700 22701 22702 22707 22726 22727 22733 22798 22799 22800 22801 22802 22803 22804 22806
22807 22808 22809 22810 22811 22812 22813 22815 22816 22818 22819 22820 22821 22935 22936 22937 22938 22939 22940 22941 22942 22943
22947 22954 22960 22961 22967 22968 22981 22983 22988 22994 23000 23001 23004 23005 23006 23009 23014 23017 23018 23019 23020 23021
23023 23025 23027 23028 23029 23030 23031 23032 23033 23035 23036 23037 23038 23039 23040 23041 23042 23043 23044 23045 23046 23047
23048 23049 23050 23053 23054 23055 23056 23057 23059 23060 23061 23062 23063 23064 23065 23066 23067 23068 23069 23070 23071 23072
23073 23075 23206 23219 23220 23221 23226 23237 23238 23242 23545 23547 23548 23549 23577 23663 23664 23665 23666 23667 23668
]])
register("world", [[
11938 17070 17111 17112 17113 17962 17963 17964 17965 17969 18202 18204 18208 18541 18542 18543 18544 18545 18546 18547 18665 18704
19130 19131 19132 19133 19134 19135 20381 20577 20578 20579 20580 20581 20582 20599 20600 20615 20616 20617 20618 20619 20621 20622
20623 20624 20625 20626 20627 20628 20629 20630 20631 20632 20633 20634 20635 20636 20637 20638 20639 20644
]])
register("other", [[
]])
content.quests[6643] = "mc"
content.quests[6644] = "mc"
content.quests[6645] = "mc"
content.quests[6646] = "mc"
content.quests[7490] = "onyxia"
content.quests[7491] = "onyxia"
content.quests[7493] = "onyxia"
content.quests[7495] = "onyxia"
content.quests[7496] = "onyxia"
content.quests[7497] = "onyxia"
content.quests[7521] = "mc"
content.quests[7604] = "mc"
content.quests[7632] = "mc"
content.quests[7633] = "mc"
content.quests[7634] = "world"
content.quests[7635] = "onyxia"
content.quests[7636] = "mc"
content.quests[7786] = "mc"
content.quests[7787] = "mc"
content.quests[8053] = "zg"
content.quests[8054] = "zg"
content.quests[8055] = "zg"
content.quests[8056] = "zg"
content.quests[8057] = "zg"
content.quests[8058] = "zg"
content.quests[8059] = "zg"
content.quests[8060] = "zg"
content.quests[8061] = "zg"
content.quests[8062] = "zg"
content.quests[8063] = "zg"
content.quests[8064] = "zg"
content.quests[8065] = "zg"
content.quests[8066] = "zg"
content.quests[8067] = "zg"
content.quests[8068] = "zg"
content.quests[8069] = "zg"
content.quests[8070] = "zg"
content.quests[8071] = "zg"
content.quests[8072] = "zg"
content.quests[8073] = "zg"
content.quests[8074] = "zg"
content.quests[8075] = "zg"
content.quests[8076] = "zg"
content.quests[8077] = "zg"
content.quests[8078] = "zg"
content.quests[8079] = "zg"
content.quests[8183] = "zg"
content.quests[8184] = "zg"
content.quests[8185] = "zg"
content.quests[8186] = "zg"
content.quests[8187] = "zg"
content.quests[8188] = "zg"
content.quests[8189] = "zg"
content.quests[8190] = "zg"
content.quests[8191] = "zg"
content.quests[8192] = "zg"
content.quests[8195] = "zg"
content.quests[8201] = "zg"
content.quests[8238] = "zg"
content.quests[8239] = "zg"
content.quests[8240] = "zg"
content.quests[8288] = "bwl"
content.quests[8301] = "bwl"
content.quests[8302] = "bwl"
content.quests[8303] = "bwl"
content.quests[8305] = "bwl"
content.quests[8446] = "world"
content.quests[8447] = "world"
content.quests[8519] = "bwl"
content.quests[8544] = "aq40"
content.quests[8555] = "bwl"
content.quests[8556] = "aq20"
content.quests[8557] = "aq20"
content.quests[8558] = "aq20"
content.quests[8559] = "aq40"
content.quests[8560] = "aq40"
content.quests[8561] = "aq40"
content.quests[8562] = "aq40"
content.quests[8575] = "bwl"
content.quests[8576] = "bwl"
content.quests[8577] = "bwl"
content.quests[8578] = "bwl"
content.quests[8584] = "bwl"
content.quests[8585] = "bwl"
content.quests[8586] = "bwl"
content.quests[8587] = "bwl"
content.quests[8592] = "aq40"
content.quests[8593] = "aq40"
content.quests[8594] = "aq40"
content.quests[8596] = "aq40"
content.quests[8597] = "bwl"
content.quests[8598] = "bwl"
content.quests[8602] = "aq40"
content.quests[8603] = "aq40"
content.quests[8606] = "bwl"
content.quests[8620] = "bwl"
content.quests[8621] = "aq40"
content.quests[8622] = "aq40"
content.quests[8623] = "aq40"
content.quests[8624] = "aq40"
content.quests[8625] = "aq40"
content.quests[8626] = "aq40"
content.quests[8627] = "aq40"
content.quests[8628] = "aq40"
content.quests[8629] = "aq40"
content.quests[8630] = "aq40"
content.quests[8631] = "aq40"
content.quests[8632] = "aq40"
content.quests[8633] = "aq40"
content.quests[8634] = "aq40"
content.quests[8637] = "aq40"
content.quests[8638] = "aq40"
content.quests[8639] = "aq40"
content.quests[8640] = "aq40"
content.quests[8641] = "aq40"
content.quests[8655] = "aq40"
content.quests[8656] = "aq40"
content.quests[8657] = "aq40"
content.quests[8658] = "aq40"
content.quests[8659] = "aq40"
content.quests[8660] = "aq40"
content.quests[8661] = "aq40"
content.quests[8662] = "aq40"
content.quests[8663] = "aq40"
content.quests[8664] = "aq40"
content.quests[8665] = "aq40"
content.quests[8666] = "aq40"
content.quests[8667] = "aq40"
content.quests[8668] = "aq40"
content.quests[8669] = "aq40"
content.quests[8689] = "aq20"
content.quests[8690] = "aq20"
content.quests[8691] = "aq20"
content.quests[8692] = "aq20"
content.quests[8693] = "aq20"
content.quests[8694] = "aq20"
content.quests[8695] = "aq20"
content.quests[8696] = "aq20"
content.quests[8697] = "aq20"
content.quests[8698] = "aq20"
content.quests[8699] = "aq20"
content.quests[8700] = "aq20"
content.quests[8701] = "aq20"
content.quests[8702] = "aq20"
content.quests[8703] = "aq20"
content.quests[8704] = "aq20"
content.quests[8705] = "aq20"
content.quests[8706] = "aq20"
content.quests[8707] = "aq20"
content.quests[8708] = "aq20"
content.quests[8709] = "aq20"
content.quests[8710] = "aq20"
content.quests[8711] = "aq20"
content.quests[8712] = "aq20"
content.quests[8728] = "bwl"
content.quests[8729] = "bwl"
content.quests[8730] = "bwl"
content.quests[8733] = "bwl"
content.quests[8734] = "bwl"
content.quests[8735] = "bwl"
content.quests[8736] = "bwl"
content.quests[8741] = "bwl"
content.quests[8742] = "bwl"
content.quests[8743] = "bwl"
content.quests[8745] = "bwl"
content.quests[8748] = "aq40"
content.quests[8749] = "aq40"
content.quests[8750] = "aq40"
content.quests[8751] = "aq40"
content.quests[8753] = "aq40"
content.quests[8754] = "aq40"
content.quests[8755] = "aq40"
content.quests[8756] = "aq40"
content.quests[8758] = "aq40"
content.quests[8759] = "aq40"
content.quests[8760] = "aq40"
content.quests[8761] = "aq40"
content.quests[8764] = "aq20"
content.quests[8765] = "aq20"
content.quests[8766] = "aq20"
content.quests[8789] = "aq40"
content.quests[8790] = "aq40"
content.quests[8791] = "aq20"
content.quests[8801] = "aq40"
content.quests[8802] = "aq40"
content.quests[9034] = "naxx"
content.quests[9036] = "naxx"
content.quests[9037] = "naxx"
content.quests[9038] = "naxx"
content.quests[9039] = "naxx"
content.quests[9040] = "naxx"
content.quests[9041] = "naxx"
content.quests[9042] = "naxx"
content.quests[9043] = "naxx"
content.quests[9044] = "naxx"
content.quests[9045] = "naxx"
content.quests[9046] = "naxx"
content.quests[9047] = "naxx"
content.quests[9048] = "naxx"
content.quests[9049] = "naxx"
content.quests[9050] = "naxx"
content.quests[9054] = "naxx"
content.quests[9055] = "naxx"
content.quests[9056] = "naxx"
content.quests[9057] = "naxx"
content.quests[9058] = "naxx"
content.quests[9059] = "naxx"
content.quests[9060] = "naxx"
content.quests[9061] = "naxx"
content.quests[9068] = "naxx"
content.quests[9069] = "naxx"
content.quests[9070] = "naxx"
content.quests[9071] = "naxx"
content.quests[9072] = "naxx"
content.quests[9073] = "naxx"
content.quests[9074] = "naxx"
content.quests[9075] = "naxx"
content.quests[9077] = "naxx"
content.quests[9078] = "naxx"
content.quests[9079] = "naxx"
content.quests[9080] = "naxx"
content.quests[9081] = "naxx"
content.quests[9082] = "naxx"
content.quests[9083] = "naxx"
content.quests[9084] = "naxx"
content.quests[9086] = "naxx"
content.quests[9087] = "naxx"
content.quests[9088] = "naxx"
content.quests[9089] = "naxx"
content.quests[9090] = "naxx"
content.quests[9091] = "naxx"
content.quests[9092] = "naxx"
content.quests[9093] = "naxx"
content.quests[9095] = "naxx"
content.quests[9096] = "naxx"
content.quests[9097] = "naxx"
content.quests[9098] = "naxx"
content.quests[9099] = "naxx"
content.quests[9100] = "naxx"
content.quests[9101] = "naxx"
content.quests[9102] = "naxx"
content.quests[9103] = "naxx"
content.quests[9104] = "naxx"
content.quests[9105] = "naxx"
content.quests[9106] = "naxx"
content.quests[9107] = "naxx"
content.quests[9108] = "naxx"
content.quests[9109] = "naxx"
content.quests[9110] = "naxx"
content.quests[9111] = "naxx"
content.quests[9112] = "naxx"
content.quests[9113] = "naxx"
content.quests[9114] = "naxx"
content.quests[9115] = "naxx"
content.quests[9116] = "naxx"
content.quests[9117] = "naxx"
content.quests[9118] = "naxx"
content.quests[9120] = "naxx"
content.quests[9230] = "naxx"
content.quests[9232] = "naxx"
content.quests[9234] = "naxx"
content.quests[9235] = "naxx"
content.quests[9236] = "naxx"
content.quests[9237] = "naxx"
content.quests[9238] = "naxx"
content.quests[9239] = "naxx"
content.quests[9240] = "naxx"
content.quests[9241] = "naxx"
content.quests[9242] = "naxx"
content.quests[9243] = "naxx"
content.quests[9244] = "naxx"
content.quests[9245] = "naxx"
content.quests[9246] = "naxx"
content.quests[9250] = "naxx"
content.quests[9251] = "aq40"
content.quests[9257] = "aq40"
content.quests[9269] = "aq40"
content.quests[9270] = "aq40"
content.quests[9271] = "aq40"

content.choices = {
    { "pvp", "PvP-Händler" },
    { "mc", "Geschmolzener Kern" }, { "onyxia", "Onyxias Hort" },
    { "bwl", "Pechschwingenhort" }, { "zg", "Zul'Gurub / Stamm der Zandalar" },
    { "aq20", "Ruinen von Ahn'Qiraj (20)" }, { "aq40", "Tempel von Ahn'Qiraj / Brut Nozdormus" },
    { "naxx", "Naxxramas" }, { "world", "Klassische Weltbosse" }, { "other", "Weitere Raids" },
}
local valid = {}
for _, choice in ipairs(content.choices) do valid[choice[1]] = true end
local areas = { [2717] = "mc", [2159] = "onyxia", [2677] = "bwl", [1977] = "zg",
    [3429] = "aq20", [3428] = "aq40", [3456] = "naxx" }
local instances = { [409] = "mc", [249] = "onyxia", [469] = "bwl", [309] = "zg",
    [509] = "aq20", [531] = "aq40", [533] = "naxx" }
local aliases = {
    moltencore = "mc", geschmolzenerkern = "mc", onyxia = "onyxia", onyxiaslair = "onyxia",
    onyxiaslairnew = "onyxia", onyxiashort = "onyxia",
    blackwinglair = "bwl", pechschwingenhort = "bwl", zulgurub = "zg",
    theruinsofahnqiraj = "aq20", ruinsofahnqiraj = "aq20", ruinenvonahnqiraj = "aq20",
    thetempleofahnqiraj = "aq40", templeofahnqiraj = "aq40", tempelvonahnqiraj = "aq40",
    ahnqiraj = "aq40", naxxramas = "naxx", worldbosses = "world", weltbosse = "world",
}
local function normalized(value)
    return type(value) == "string" and value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower():gsub("[%p%s]", "") or ""
end
function content.LocationGroup(location)
    if not location then return end
    -- UBRS is open even if a provider classifies the ten-player dungeon as a raid.
    local name = normalized(location.key or location.name)
    if location.instanceID == 229 or name == "upperblackrockspire" or name == "obereschwarzfelsspitze" then return end
    return instances[location.instanceID] or areas[location.map]
        or aliases[name] or aliases[normalized(location.name)] or aliases[normalized(location.localName)]
        or (location.kind == "raid" and "other" or nil)
end
function content.Snapshot()
    PaulchenQoLUpgradesDB = PaulchenQoLUpgradesDB or {}
    local db = PaulchenQoLUpgradesDB
    if type(db.contentReleases) ~= "table" then db.contentReleases = {} end
    local result = {}
    for key in pairs(valid) do
        result[key] = db.contentReleases[key] == true or key == "world" and db.contentReleases[key] == nil
    end
    return result
end
function content.SetEnabled(key, enabled)
    if not valid[key] then return end
    content.Snapshot()
    PaulchenQoLUpgradesDB.contentReleases[key] = enabled == true
end
function content.LocationAllowed(scan, location)
    local group = content.LocationGroup(location)
    return not group or (scan.content or content.Snapshot())[group] == true
end
function content.ItemAllowed(scan, id)
    local groups = content.items[id]
    if not groups then return true end
    local releases = scan.content or content.Snapshot()
    for group in pairs(groups) do if releases[group] then return true end end
    return false
end
function content.NoteItem(id, location)
    local group = content.LocationGroup(location)
    if group then
        local entry = content.items[id] or {}
        entry[group], content.items[id] = true, entry
    end
end
function content.QuestAllowed(scan, id, quest, codex, visiting)
    local releases = scan.content or content.Snapshot()
    local group = content.quests[id] or quest and areas[quest.zone]
    if group and not releases[group] then return false end
    if codex then
        local faction = codex.repFaction
        if faction == 270 and not releases.zg or faction == 910 and not releases.aq40
            or faction == 749 and not releases.mc then return false end
        -- A chain outside the raid still inherits its mandatory raid prerequisite.
        visiting = visiting or {}
        if visiting[id] then return true end
        visiting[id] = true
        for _, pre in ipairs(codex.pre or {}) do
            local q = Polestar and Polestar.Codex and Polestar.Codex.Quest(pre)
            if not content.QuestAllowed(scan, pre, nil, q, visiting) then visiting[id] = nil; return false end
        end
        visiting[id] = nil
    end
    return true
end
