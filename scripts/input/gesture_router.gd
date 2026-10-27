extends RefCounted

# 手势路由（架构 v6：仅模型空白区起始指针产生旋转意图；UI 起始永不旋转；取消/失焦清空；中心不漂移）
# 阶段：阶段3。D06 默认：单指拖拽、多指只认首指
# 2026-10-27 P1（交互打磨方案 §3.1）：只提供已归属指针的原始像素位移/按下释放，
# 不再维护内部角度/灵敏度/俯仰钳制——唯一姿态状态在 GameController（yaw/pitch），
# 弧度换算（分轴灵敏度）在 main，姿态钳制与应用在控制器 step() 顶部统一执行。

var mutex: RefCounted    # InputMutex
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


# 拖动：返回已归属旋转指针的原始像素位移；非旋转指针返回零向量（调用方负责灵敏度换算）
func handle_drag(pointer_id: int, delta: Vector2) -> Vector2:
	if pointer_id != _active_pointer or mutex.owner_of(pointer_id) != "model":
		return Vector2.ZERO
	return delta


func handle_release(pointer_id: int) -> void:
	if pointer_id == _active_pointer:
		_active_pointer = -1
	mutex.release(pointer_id)


func cancel_all() -> void:
	_active_pointer = -1
	mutex.clear_all()
