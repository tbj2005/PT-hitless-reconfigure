# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06约23日
"""
import numpy as np


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


inputs = NetworkInformation()
inputs.nodes_num = 4
inputs.group_num = 2
inputs.oxc_ports = 12
inputs.oxc_num_a_group = 1
inputs.connection_cap = 1
inputs.physical_conn_oxc = 3
inputs.max_hop = 2
inputs.resi_cap = 0.65
inputs.method = 3

max_links_in_nodes = inputs.physical_conn_oxc
Logical_topo_init = np.zeros([inputs.nodes_num, inputs.nodes_num])
