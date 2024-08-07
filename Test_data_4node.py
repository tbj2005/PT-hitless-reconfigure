# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06约23日
"""
import time

# 用于仿真 5pod 场景下物理拓扑的计算和平滑重构的调度

import numpy as np
import Input_class
import distr_Traffic
import convert_inputs
import physical_topo_fu
import target_topo_convert
import hitless_reconfig_v3_2

inputs = Input_class.NetworkInformation()
inputs.nodes_num = 4  # 网络输入参数方案见 class 内注释
inputs.group_num = 2
inputs.oxc_ports = 12
inputs.oxc_num_a_group = 1
inputs.connection_cap = 1
inputs.physical_conn_oxc = 3
inputs.max_hop = 2
inputs.resi_cap = 0.65

inputs.request = [[2, 3, 2], [1, 4, 2]]  # 两种流量需求输入，网络流量少，可以平滑重构
# inputs.request = [[2, 3, 3], [1, 4, 3], [2, 4, 1]]  # 网络流量较满，无法平滑重构的情况

T = inputs.group_num
K = inputs.oxc_num_a_group

for m in range(1, 3):
    inputs.method = m

    logical_topo = np.empty((T, K), dtype=object)
    logical_topo_cap = np.empty((T, K), dtype=object)
    ## 测试例子 1 
    # # group 1 逻辑子拓扑
    # logical_topo[0, 0] = np.array([[0, 1, 1, 1],[1, 0, 1, 1],[1, 1, 0 ,1],[1, 1, 1, 0]])
    # # group 2 逻辑子拓扑
    # logical_topo[1, 0] = np.array([[0, 1, 2, 0],[1, 0, 0, 2],[2, 0, 0, 0],[0, 2, 0, 0]])
    ## 测试例子 2 (mini_rewiring:stage 2, our proposal: stage 1)
    # # group 1 逻辑子拓扑
    # logical_topo[0, 0] = np.array([[0, 1, 1, 1],[1, 0, 1, 1],[1, 1, 0 ,0],[1, 1, 0, 0]])
    # # group 2 逻辑子拓扑
    # logical_topo[1, 0] = np.array([[0, 2, 0, 0],[2, 0, 0, 1],[0, 0, 0, 1],[0, 1, 1, 0]])
    # ## 测试例子 3
    # group 1 逻辑子拓扑
    logical_topo[0, 0] = np.array([[0, 1, 1, 1], [1, 0, 1, 1], [1, 1, 0, 0], [1, 1, 0, 0]])
    # group 2 逻辑子拓扑
    logical_topo[1, 0] = np.array([[0, 1, 0, 0], [1, 0, 0, 1], [0, 0, 0, 0], [0, 1, 0, 0]])
    ##

    # 逻辑拓扑对应的带宽量
    logical_topo_cap[0, 0] = logical_topo[0, 0] * inputs.connection_cap
    logical_topo_cap[1, 0] = logical_topo[1, 0] * inputs.connection_cap
    Logical_topo_init_conn = logical_topo[0, 0] + logical_topo[1, 0]
    Logical_topo_init_cap = logical_topo_cap[0, 0] + logical_topo_cap[1, 0]
    # 目标逻辑拓扑
    Logical_topo_desi = np.array([[0, 1, 2, 2], [1, 0, 2, 3], [2, 2, 0, 1], [2, 3, 1, 0]])
    start = time.time()
    traffic_distr, flow_path, _, _ = distr_Traffic.distr_Traffic(Logical_topo_init_cap, inputs)

    S, R, logical_topo_traffic, S_Conn_cap, port_allocation_inti_topo, port_allocation = convert_inputs.convert_inputs(
        inputs, flow_path, logical_topo)

    delta_topology = Logical_topo_desi - Logical_topo_init_conn

    update_logical_topo, _ = physical_topo_fu.physical_topo_fu(inputs, delta_topology, logical_topo_traffic,
                                                               logical_topo, logical_topo_cap, 100)

    E = target_topo_convert.target_topo_convert(S_Conn_cap, S, logical_topo, update_logical_topo,
                                                port_allocation_inti_topo, inputs)

    stage = hitless_reconfig_v3_2.hitless_reconfigure(S, E, R, inputs, port_allocation)
    end = time.time()
    # print('stage:', stage, 'time:', end - start)
