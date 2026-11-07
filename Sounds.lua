local Menu=RedsQOL; local CD={}; Menu.Cooldowns=CD; CD.HasGameManager=function() return (select(4,GetBuildInfo()) or 0)>=16000 end; local SND="Interface\\AddOns\\RedsQOL\\Media\\Sounds\\"
local SOUNDS={{"bell","Bell","IG_QUEST_LIST_COMPLETE",878},{"warn","Raid warning","RAID_WARNING",8959},{"ready","Ready check","READY_CHECK",8960},
 {"alarm","Alarm","ALARM_CLOCK_WARNING_3",12889},{"ping","Ping","MAP_PING",3175},{"whisper","Whisper","TELL_MESSAGE",3081},
 -- quick chimes and dings: the game's own (foreverOnly: only WoW Forever's build has it)
 {"ding","Ding (quest complete)",file=567439},{"chime","Chime (quest found)",file=567400},{"toast","Chime (friend online)",file=567402},
 {"auction","Chime (auction house)",file=567482},{"levelup","Level up",file=567431},{"levelup2","Level up 2",file=567478},
 {"coin","Coin",file=567428},{"coins","Coins (kaching)",file=567413},{"clink","Clink (ring)",file=567551},{"queue","Queue pop",file=568011},
 {"alarm1","Alarm clock 1",file=567436},{"alarm2","Alarm clock 2",file=567399},{"horn","Horn (PvP warning)",file=567488},
 {"failed","Quest failed",file=567459},{"bosswhisper","Boss whisper alert",file=876098,foreverOnly=true},{"epic","Epic loot",file=642829,foreverOnly=true},
 -- Red's own (Media\Sounds), all CC0 / public domain from OpenGameArt: Short alarm (yd), Alarm (EZduzziteh), Sonar ping (Spiceman),
 -- Beep, Water drop and Bubbles (jcpmcdonald), and the UI sound pack (Robin Lamb): chimes, dings, blip, alarm, dum, buzzes
 {"r_chimes","Chimes",file=SND.."Chimes.ogg"},{"r_ding","Ding",file=SND.."Ding.ogg"},{"r_dingdeep","Deep ding",file=SND.."DingDeep.ogg"},
 {"r_blip","Blip",file=SND.."Blip.ogg"},{"r_beep","Beep",file=SND.."Beep.ogg"},{"r_dum","Dum",file=SND.."Dum.ogg"},
 {"r_sonar","Sonar ping",file=SND.."SonarPing.mp3"},{"r_water","Water drop",file=SND.."WaterDrop.ogg"},{"r_bubbles","Bubbles",file=SND.."Bubbles.ogg"},
 {"r_salarm","Short alarm",file=SND.."ShortAlarm.ogg"},{"r_alarm","Alarm",file=SND.."Alarm.ogg"},{"r_alarm2","Alarm 2",file=SND.."Alarm2.ogg"},
 {"r_buzz","Buzz",file=SND.."Buzz.ogg"},{"r_buzz2","Buzz 2",file=SND.."Buzz2.ogg"},
 -- (the meow is Red's own: Media\Sounds\Meow.ogg, "Meow" by IgnasD on OpenGameArt, CC0 / public domain)
 -- (and Media\Sounds\KittenMew.ogg, "Kitten Mew" by AntumDeluge on OpenGameArt, CC0 / public domain)
 {"meow","Cat meow",file="Interface\\AddOns\\RedsQOL\\Media\\Sounds\\Meow.ogg"},
 {"meow2","Cat meow 2",file="Interface\\AddOns\\RedsQOL\\Media\\Sounds\\KittenMew.ogg"},{"bark","Dog bark",file=564215},
 {"vready","Male: \"isn't ready yet\"",file=540793},{"vmana","Male: \"not enough mana\"",file=540803},{"vrange","Male: \"out of range\"",file=540759},
 {"fready","Female: \"isn't ready yet\"",file=540550},{"fmana","Female: \"not enough mana\"",file=540588},{"frange","Female: \"out of range\"",file=540551},
 -- more animals, and the orcs: the game's peons ("work work", "zug zug") and the orc war cries
 {"bark2","Dog bark 2",file=564229},{"bark3","Dog bark 3",file=564222},
 -- (named by when the game says them: "yes" has zug zug and work work, "pissed" has me not that kind of orc, the grunt has lok'tar)
 {"peon1","Peon yes 1",file=558136},{"peon2","Peon yes 2",file=558139},{"peon3","Peon yes 3",file=558147},{"peon4","Peon yes 4",file=558140},
 {"peon5","Peon go 1",file=558145},{"peon6","Peon go 2",file=558138},
 {"peonp1","Peon pissed 1",file=558133},{"peonp2","Peon pissed 2",file=558144},{"peonp3","Peon pissed 3",file=558142},{"peonp4","Peon pissed 4",file=558146},
 {"grunt0","Grunt war cry",file=551328},{"grunt1","Grunt go 1",file=551331},{"grunt2","Grunt go 2",file=551330},{"grunt3","Grunt go 3",file=551332},
 {"orc1","Orc war cry 1",file=541389},{"orc2","Orc war cry 2",file=541391},{"orc3","Orc war cry 3",file=541400},
 {"orca1","Orc attack call 1",file=541417},{"orca2","Orc attack call 2",file=541407},{"orca3","Orc attack call 3",file=541384}}
-- Sounds other addons share (BigWigs, DBM and anything else that puts its sounds into SharedMedia): listed after Red's own, by the
-- name that addon gave them. Their keys start "lsm:".
local function Shared() return LibStub and LibStub("LibSharedMedia-3.0",true) end
function CD.AllSounds()
 local list={}
 local forever=CD.HasGameManager and CD.HasGameManager()
 for _,x in ipairs(SOUNDS) do if forever or not x.foreverOnly then list[#list+1]={x[1],x[2]} end end
 local LSM=Shared()
 if LSM then
  local names=LSM:List("sound") or {}
  for _,n in ipairs(names) do if n~="None" then list[#list+1]={"lsm:"..n,n,shared=true} end end
 end
 return list
end
local function SoundName(k)
 if type(k)=="string" and k:sub(1,4)=="lsm:" then return k:sub(5) end
 for _,x in ipairs(SOUNDS) do if x[1]==k then return x[2] end end
end
function CD.PlaySound(k)
 if type(k)=="string" and k:sub(1,4)=="lsm:" then
  local LSM=Shared();local path=LSM and LSM:Fetch("sound",k:sub(5),true)
  if path then pcall(PlaySoundFile,path,"Master") end
  return
 end
 for _,x in ipairs(SOUNDS) do
  if x[1]==k then
   if x.file then
    local file=(x.forever and CD.HasGameManager and CD.HasGameManager()) and x.forever or x.file
    pcall(PlaySoundFile,file,"Master")
   else local id=(SOUNDKIT and SOUNDKIT[x[3]]) or x[4];pcall(PlaySound,id,"Master") end
   return
  end
 end
end
