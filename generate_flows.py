# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年07约04日
"""
import random

import numpy as np


def ger_flows(inputs, Logical_topo_init_cap, topo_index):
    flow_requests = []
    flow_requests_num = 0
    sour_row, dest_col = np.where(np.triu(Logical_topo_init_cap))
    while flow_requests_num < inputs.num_requests:
        if len(sour_row) == 0:
            break

        hop1_ava_req = len(sour_row)
        rand_req_ind = random.randint(0, hop1_ava_req - 1)
        source = sour_row[rand_req_ind]
        destination = dest_col[rand_req_ind]
        sour_row = np.delete(sour_row, rand_req_ind)
        dest_col = np.delete(dest_col, rand_req_ind)

        update_total_bandwidth = 0
        total_bandwidth = round((inputs.group_num * inputs.oxc_ports * inputs.oxc_num_a_group *
                                 inputs.connection_cap / 2) * inputs.cap_ratio)

        update_total_bandwidth = total_bandwidth - update_total_bandwidth

        if update_total_bandwidth > 0:
            ava_band_1hop = Logical_topo_init_cap[source][destination]

            ava_bandwidth = 0

            ava_bandwidth += ava_band_1hop

            max_val = min(ava_bandwidth, update_total_bandwidth)
            if max_val != 0:
                require_bandwidth_band = random.randint(1, max_val)
                update_total_bandwidth -= require_bandwidth_band
                flow_requests.append([source + 1, destination + 1, require_bandwidth_band])
                flow_requests_num += 1

    return flow_requests
