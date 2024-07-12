# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06约23日
"""


# 定义 OXC 各项数据

# OXC_information class建立
class NetworkInformation:
    def __init__(self):
        self.nodes_num = 0  # 网络中的 pod 数目
        self.group_num = 0  # ROL 中 OXC 的组数
        self.oxc_ports = 0  # 单个 OXC 上可以提供的 port 对数
        self.oxc_num_a_group = 0  # 一组 OXC 的个数
        self.connection_cap = 0  # 一个 OXC 连接可以提供的带宽容量
        self.physical_conn_oxc = 0  # 一个 pod 可以连接的物理链路数目
        self.max_hop = 0  # 通信跳数限定
        self.resi_cap = 0  # 平滑重构时空闲容量占比 \eta
        self.method = 0  # 物理拓扑计算方案，取值1-3
        self.request = []  # 通信需求三元组[S, D, R]
        self.cap_ratio = []
        self.num_requests = 0  # 流量需求数目


class StimulateInformation:
    def __init__(self):
        self.nodes_num = []  # 存储多种仿真场景下网络中 pod 数目的数组
        self.group_num = []  # 存储 group 数目
        self.oxc_ports = []  # 存储单 OXC 提供的 port 数目
        self.oxc_num_a_group = []  # 存储一个 group 中的 OXC 数目
        self.connection_cap = []  # 存储一个 OXC 连接提供的带宽容量
        self.physical_conn_oxc = []  # 存储一个 pod 可以连接的物理链路数目
        self.max_num_requests = []
        self.cap_ratio = []


class Request:
    def __int__(self):
        self.source = 0  # 需求流量的源 pod
        self.destination = 0  # 需求流量的目的 pod
        self.demands = 0  # 需求流量的带宽需求
        self.route = []  # 需求流量的路由方案


class DeltaTopology:
    def __init__(self):
        self.delta_topo_delete_weight = 0
        self.delta_topo_delete = 0
        self.delta_topo_add = 0


class LP:
    def __init__(self):
        self.logical_topo_cap = 0
        self.logical_topo = 0


class UP:
    def __init__(self):
        self.update_logical_topo_cap = 0
        self.update_logical_topo = 0
        self.update_delta_add_topo = 0
        self.update_delta_delete_topo_ed = 0
        self.update_delta_topo_delete = 0
