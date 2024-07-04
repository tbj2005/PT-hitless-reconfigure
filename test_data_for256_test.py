# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年07约04日
"""

import time

# 用于仿真 5pod 场景下物理拓扑的计算和平滑重构的调度

import numpy as np
import Input_class
import distr_Traffic
import convert_inputs
import physical_topo_fu
import target_topo_convert
import hitless_reconfig_v3

Stimulate = Input_class.StimulateInformation()
Stimulate.nodes_num = [8, 16, 32, 64, 128, 256]
Stimulate.group_num = [1, 1, 1, 1, 1, 1]
Stimulate.oxc_ports = [8 * 3, 16 * 3, 32 * 3, 64 * 3, 128 * 3, 256 * 4]
Stimulate.oxc_num_a_group = [1, 1, 1, 1, 1, 1]
Stimulate.connection_cap = [100, 100, 100, 100, 100, 100]
Stimulate.physical_conn_oxc = [Stimulate.oxc_ports[i] / Stimulate.nodes_num[i] for i in range(0, len(Stimulate.nodes_num))]

Stimulate.max_num_requests = [10, 20, 30, 400, 800, 1000]
Stimulate.cap_ratio = [0.01, 0.03, 0.05, 0.07, 0.09]

topo_index = 1

for i in range(4, 6):
    inputs = Input_class.NetworkInformation()
    inputs.nodes_num = Stimulate.nodes_num[i]
    inputs.group_num = Stimulate.group_num[i]
    inputs.oxc_ports = Stimulate.oxc_ports[i]
    inputs.oxc_num_a_group = Stimulate.oxc_num_a_group[i]
    inputs.connection_cap = inputs.connection_cap[i]
    inputs.physical_conn_oxc = inputs.physical_conn_oxc[i]
    inputs.cap_ratio = 0.6

    inputs.max_hop = 2
    inputs.resi_cap = 0.75

    for j in range(1, 2):
        inputs.num_requests = j


