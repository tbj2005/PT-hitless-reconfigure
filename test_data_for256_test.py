# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年07约04日
"""
import copy
import time

# 用于仿真 8 - 256 pod 场景下物理拓扑的计算和平滑重构的调度

import numpy as np
import Input_class
import generate_topo
import generate_flows
import distr_Traffic
import convert_inputs
import physical_topo_fu
import target_topo_convert
import hitless_reconfig_v3

Stimulate = Input_class.StimulateInformation()
# 大规模仿真支持自定义规模，默认 6 种规模，具体元素意义见结构体注释
Stimulate.nodes_num = [8, 16, 32, 64, 128, 256]
Stimulate.group_num = [1, 1, 1, 1, 1, 1]
Stimulate.oxc_ports = [8 * 3, 16 * 3, 32 * 3, 64 * 3, 128 * 3, 256 * 4]
Stimulate.oxc_num_a_group = [1, 1, 1, 1, 1, 1]
Stimulate.connection_cap = [100, 100, 100, 100, 100, 100]
Stimulate.physical_conn_oxc = [int(Stimulate.oxc_ports[i] / Stimulate.nodes_num[i]) for i in
                               range(0, len(Stimulate.nodes_num))]

# Stimulate.max_num_requests = [10, 20, 30, 400, 800, 1000]
# Stimulate.cap_ratio = [0.01, 0.03, 0.05, 0.07, 0.09]

topo_index = 1

for i in range(5, 6):
    # 每次循环跑一种规模，每次循环的输入从数组中取得
    inputs = Input_class.NetworkInformation()
    inputs.nodes_num = Stimulate.nodes_num[i]
    inputs.group_num = Stimulate.group_num[i]
    inputs.oxc_ports = Stimulate.oxc_ports[i]
    inputs.oxc_num_a_group = Stimulate.oxc_num_a_group[i]
    inputs.connection_cap = Stimulate.connection_cap[i]
    inputs.physical_conn_oxc = Stimulate.physical_conn_oxc[i]
    inputs.cap_ratio = 0.6

    inputs.max_hop = 2
    inputs.resi_cap = 0.75

    for j in range(1, 2):
        # 需求流量数目
        inputs.num_requests = 10

        # 随机产生初始逻辑拓扑
        Logical_topo_init_conn, Logical_topo_init_cap, logical_topo, logical_topo_cap, _ = (
            generate_topo.gener_topo(inputs, topo_index))

        # 随机产生流量
        flow_request = generate_flows.ger_flows(inputs, Logical_topo_init_cap, topo_index)

        inputs.request = flow_request

        # 判断流量是否可以在两跳路径内完全依靠初始逻辑拓扑转发
        _, _, breakflag0, unava_flow_ini = distr_Traffic.distr_Traffic(Logical_topo_init_cap, inputs)

        # 随机产生目标逻辑拓扑
        Logical_topo_desi, Logical_topo_target_cap, logical_topo_desi, _, _ = (
            generate_topo.gener_topo(inputs, topo_index))

        # 判断流量是否可以在两跳路径内完全依靠目标逻辑拓扑转发
        _, _, breakflag1, unava_flow_tar = distr_Traffic.distr_Traffic(Logical_topo_target_cap, inputs)

        if breakflag1 == 1 or breakflag0 == 1:
            # 如果初始逻辑拓扑和目标逻辑拓扑任意一个无法在两跳内满足流量需求
            cannot_serflow = []
            for i_r in range(0, len(unava_flow_ini)):
                current_row = unava_flow_ini[i_r][0:2]
                matching_rows = \
                    [1 if unava_flow_tar[k][0:2] == current_row else 0 for k in range(0, len(unava_flow_tar))]
                if sum(matching_rows) > 0:
                    match_index = np.where(matching_rows)[0]

                    max_value = max([unava_flow_ini[i_r][2]] + [unava_flow_tar[match_index[k]][2] for k in
                                                                range(0, len(match_index))])

                    cannot_serflow.append([current_row[0], current_row[1], max_value])
                else:
                    cannot_serflow = []

            # 如果存在不能服务的流量，则修改 request
            if len(cannot_serflow) > 0:
                re_cols = [inputs.request[k][0:2] for k in range(0, len(inputs.request))]
                match_index_A = - 1 * np.ones(len(cannot_serflow))
                for k in range(0, len(cannot_serflow)):
                    if cannot_serflow[k][0:2] in [[re_cols[n][0], re_cols[n][1]] for n in range(0, len(re_cols))]:
                        match_index_A[k] = [[re_cols[n][0], re_cols[n][1]] for n in range(0, len(re_cols))].index(
                            cannot_serflow[k][0:2])

                match_index_A = match_index_A[match_index_A >= 0]
                match_index_A = match_index_A.astype(int)
                for k in range(0, len(match_index_A)):
                    inputs.request[match_index_A[k]][2] -= cannot_serflow[match_index_A[k]][2]

                bandwidth_0 = [k for k in range(0, len(inputs.request)) if inputs.request[k][2] == 0]

                # 修改 request
                inputs.request = [inputs.request[k] for k in range(0, len(inputs.request)) if k in bandwidth_0]

        traffic_distr, flow_path, breakflag0, unava_flow_ini = (
            distr_Traffic.distr_Traffic(Logical_topo_init_cap, inputs))

        RE = inputs.request

        for m in range(2, 3):
            start = time.time()
            # method 取 2,使用最小重路由方案
            inputs.method = m

            # 修改输入，使得数据转化成可供后续函数使用的形式
            S, R, logical_topo_traffic, S_Conn_cap, port_allocation_inti_topo, port_allocation = (
                convert_inputs.convert_inputs(inputs, flow_path, logical_topo))

            # 计算初始逻辑拓扑和目标逻辑拓扑的差值
            delta_topology = Logical_topo_desi - Logical_topo_init_conn

            # 计算目标物理拓扑
            update_logical_topo, update_check_flag = (
                physical_topo_fu.physical_topo_fu(inputs, delta_topology, logical_topo_traffic, logical_topo,
                                                  logical_topo_cap, 100))

            if update_check_flag == 1:
                update_logical_topo = copy.deepcopy(logical_topo_desi)

            # 将已知量转化为后续平滑重构可用的形式
            E = target_topo_convert.target_topo_convert(S_Conn_cap, S, logical_topo, update_logical_topo,
                                                        port_allocation_inti_topo, inputs)

            # 执行平滑重构算法
            stage = hitless_reconfig_v3.hitless_reconfigure(S, E, R, inputs, port_allocation)
            end = time.time()
            print('stage:', stage, 'time:', end - start)
