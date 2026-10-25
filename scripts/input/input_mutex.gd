extends RefCounted

# 输入互斥：指针归属唯一入口（架构 v6：一个指针同一时刻只属于一个 owner；取消/失焦清空）
# 阶段：阶段3

var _owner_by_pointer: Dictionary = {}  # pointer_id -> owner(String: "ui"/"model")


func try_claim(pointer_id: int, owner: String) -> bool:
	if _owner_by_pointer.has(pointer_id):
		return false
	_owner_by_pointer[pointer_id] = owner
	return true


func owner_of(pointer_id: int) -> String:
	return _owner_by_pointer.get(pointer_id, "")


func release(pointer_id: int) -> void:
	_owner_by_pointer.erase(pointer_id)


func clear_all() -> void:
	_owner_by_pointer.clear()
