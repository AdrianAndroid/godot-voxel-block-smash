extends Node
class_name AudioPresenter

## P5-05 音效绑定：turret_fire→fire、voxel_destroyed→shatter、turret_merged→merge、
## level_win→win、level_lose→lose。每个事件只播放一次（总线 event_id 去重保证不重复投递）。

const EVENT_TO_SFX := {
	"turret_fire": "fire",
	"voxel_destroyed": "shatter",
	"turret_merged": "merge",
	"level_win": "win",
	"level_lose": "lose",
}

var muted := false
var play_counts: Dictionary = {}       # sfx 名 -> 请求次数（验收计数用）

var _streams: Dictionary = {}          # sfx 名 -> AudioStream
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
const POOL_SIZE := 8


func _ready() -> void:
	for name in EVENT_TO_SFX.values():
		var p := "res://assets/audio/sfx/%s.wav" % name
		if ResourceLoader.exists(p):
			_streams[name] = load(p)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)


func attach(bus: RefCounted, level_id: String) -> void:
	for event in EVENT_TO_SFX:
		bus.subscribe(event, _on_event, level_id)


func _on_event(_args: Array, meta: Dictionary) -> void:
	var sfx: String = EVENT_TO_SFX.get(str(meta.get("event", "")), "")
	if sfx != "":
		play(sfx)


func play(sfx: String) -> bool:
	play_counts[sfx] = int(play_counts.get(sfx, 0)) + 1
	if muted or not _streams.has(sfx):
		return false
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = _streams[sfx]
	player.play()
	return true
