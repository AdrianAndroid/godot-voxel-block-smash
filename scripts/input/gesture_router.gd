extends RefCounted

# 手势路由（架构 v6：仅模型空白区起始指针产生旋转意图；UI 起始永不旋转；取消/失焦清空；中心不漂移）
# 阶段：阶段3。D06 默认：单指拖拽、0.01 弧度/像素、多指只认首指

var sensitivity := 0.01  # 弧度/像素
var mutex: RefCounted    # InputMutex
var _yaw := 0.0
var _pitch := 0.0
var _active_pointer := -1


func _init(p_mutex: RefCounted = null) -> void:
	mutex = p_mutex if p_mutex != null else preload("res://scripts/input/input_mutex.gd").new()


# 按下：over_ui=true 时声明为 UI 指针（不产生旋转）。返回是否成为旋转指针
func handle_press(pointer_id: int, over_ui: bool) -> bool:
	if over_ui:
		mutex.try_claim(pointer_id, "ui")
		return false
	if _active_pointer != -1:
		mutex.try_claim(pointer_id, "ignored")  # 多指只认首指
		return false
	if mutex.try_claim(pointer_id, "model"):
		_active_pointer = pointer_id
		return true
	return false


# 拖动：返回 (yaw_delta, pitch_delta)；非旋转指针返回零向量
func handle_drag(pointer_id: int, delta: Vector2) -> Vector2:
	if pointer_id != _active_pointer or mutex.owner_of(pointer_id) != "model":
		return Vector2.ZERO
	var rot := Vector2(delta.x * sensitivity, delta.y * sensitivity)
	_yaw += rot.x
	_pitch = clampf(_pitch + rot.y, -1.4, 1.4)
	return rot


func handle_release(pointer_id: int) -> void:
	if pointer_id == _active_pointer:
		_active_pointer = -1
	mutex.release(pointer_id)


func cancel_all() -> void:
	_active_pointer = -1
	mutex.clear_all()


func current_angles() -> Vector2:
	return Vector2(_yaw, _pitch)
