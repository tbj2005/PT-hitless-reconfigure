# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06约24日
"""
import copy

import numpy as np


# 该函数用于计算目标物理拓扑
import numpy as np


def physical_topo_fu(inputs, delta_topology, traffic_distr, logical_topo_traffic, logical_topo, logical_topo_cap):
    method = inputs.method
    delta_topo_add = copy.deepcopy(delta_topology)
    delta_topo_delete = copy.deepcopy(delta_topology)
    delta_topo_add[delta_topo_add < 0] = 0
    delta_topo_delete[delta_topo_delete > 0] = 0
    delta_topo_delete *= -1

    whole_logical_topo = np.zeros([inputs.nodes_num, inputs.nodes_num])
    whole_logical_topo_cap = whole_logical_topo * inputs.connection_cap
    update_delta_topo_add = copy.deepcopy(delta_topo_add)
    update_logical_topo = copy.deepcopy(logical_topo)
    update_logical_topo_cap = copy.deepcopy(logical_topo_cap)

    for t in range(0, inputs.nodes_num):
        for k in range(0, inputs.oxc_num_a_group):
            triu_update_delta_topo_add = np.triu(update_delta_topo_add)
            print(triu_update_delta_topo_add)
            reshape_triu_update_delta_topo_add = np.reshape(triu_update_delta_topo_add, (-1,), order='F')
            print(reshape_triu_update_delta_topo_add, type(reshape_triu_update_delta_topo_add))
            sort_add_delta_topo_ind = np.sort(reshape_triu_update_delta_topo_add)
            sub_index_col = int(sort_add_delta_topo_ind / inputs.nodes_num) + 1
            sub_index_row = sort_add_delta_topo_ind % inputs.nodes_num
            print(sub_index_row, sub_index_col)
