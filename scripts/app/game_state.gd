extends RefCounted

# 对外只读状态门面（架构 v6：提供 LevelSession/OutcomeState 已提交只读状态，不复制权威状态）
# 阶段：阶段3

var _session: RefCounted


func bind(session: RefCounted) -> void:
	_session = session


func alive_count_snapshot() -> int:
	return _session.alive_voxel_ids.size() if _session != null else 0


func outcome() -> String:
	return _session.outcome if _session != null else "RUNNING"


func level_id() -> String:
	return _session.level_id if _session != null else ""
