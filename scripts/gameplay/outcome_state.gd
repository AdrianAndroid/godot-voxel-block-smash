extends RefCounted

# 职责：完整事务后评估通关/失败，RUNNING只转一次WON或LOST
# 阶段：阶段4
# 任务：P1-INIT-v6 占位（architecture v6 目标树）
# TODO: 仅占位保证可解析；不含 class_name/信号/业务方法，不挂载节点；基类在实现阶段按职责调整。
