# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年07约04日
"""
import random

import numpy as np


def ger_flows(inputs, Logical_topo_init_cap, topo_index):
    """
    用来产生需求流量
    :param inputs:
    :param Logical_topo_init_cap:
    :param topo_index:
    :return:
    """
    flow_requests = []
    flow_requests_num = 0  # 标记流量需求数目
    sour_row, dest_col = np.where(np.triu(Logical_topo_init_cap))  # 找到一跳路径对应的所有源、目的端口
    while flow_requests_num < inputs.num_requests:
        if len(sour_row) == 0:
            # 若所有一跳路径都找完了，直接跳出循环
            break

        hop1_ava_req = len(sour_row)  # 可用一跳路径需求数
        rand_req_ind = random.randint(0, hop1_ava_req - 1)  # 随机产生一个一跳路径索引
        source = sour_row[rand_req_ind]
        destination = dest_col[rand_req_ind]
        # 找到该一跳索引的源、目的端口
        sour_row = np.delete(sour_row, rand_req_ind)
        dest_col = np.delete(dest_col, rand_req_ind)
        # 从集合中删除该一跳路径以防止下次循环无法重复选择

        update_total_bandwidth = 0
        total_bandwidth = round((inputs.group_num * inputs.oxc_ports * inputs.oxc_num_a_group *
                                 inputs.connection_cap / 2) * inputs.cap_ratio)
        # 网络中可以调度流量的最大值 / 2

        update_total_bandwidth = total_bandwidth - update_total_bandwidth  # 存储当前可使用带宽量

        if update_total_bandwidth > 0:
            ava_band_1hop = Logical_topo_init_cap[source][destination]
            # 单跳带宽量

            ava_bandwidth = 0

            ava_bandwidth += ava_band_1hop

            max_val = min(ava_bandwidth, update_total_bandwidth)
            # 取单跳带宽和可使用总带宽最小值
            if max_val != 0:
                require_bandwidth_band = random.randint(1, max_val)
                # 随机产生带宽需求
                update_total_bandwidth -= require_bandwidth_band
                flow_requests.append([source + 1, destination + 1, require_bandwidth_band])
                # 更新流量需求
                flow_requests_num += 1

    return flow_requests
