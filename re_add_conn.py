# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06月26日
"""
import copy

import numpy as np
import sub_add_conns_v2


def re_add_conns(inputs, logical_topo, Logical_topo_weight, update_delta_topo_add, update_logical_topo,
                 update_delta_topo_delete):
    """
    用来执行打断重连过程
    :param inputs:
    :param logical_topo:
    :param Logical_topo_weight:
    :param update_delta_topo_add:
    :param update_logical_topo:
    :param update_delta_topo_delete:
    :return:
    """
    index = 1
    del_update_logical_topo = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
    use_ind = []
    links_tobe_add_topo = np.zeros([inputs.nodes_num, inputs.nodes_num])
    while index <= inputs.group_num * inputs.oxc_num_a_group:
        update_logical_topo_try = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
        update_logical_topo_weight = np.empty([inputs.group_num, inputs.oxc_num_a_group, inputs.nodes_num,
                                               inputs.nodes_num], dtype=object)
        for t in range(0, inputs.group_num):
            for k in range(0, inputs.oxc_num_a_group):
                update_logical_topo_try[t][k] = copy.deepcopy(update_logical_topo[t][k])
                for i in range(0, inputs.nodes_num):
                    for j in range(0, inputs.nodes_num):
                        if update_logical_topo_try[t][k][i][j] > logical_topo[t][k][i][j]:
                            # 如果更新后该 OXC 在某 node 对之间的连接数增加了，令这部分连接的 weight 为 0
                            new_add_link_num = update_logical_topo_try[t][k][i][j] - logical_topo[t][k][i][j]
                            # 记录增加连接数
                            if len(Logical_topo_weight[t][k][i][j]) == 0:
                                update_logical_topo_weight[t][k][i][j] = [0 for _ in range(0, int(new_add_link_num))]
                            else:
                                update_logical_topo_weight[t][k][i][j] = (
                                        [0 for _ in range(0, int(new_add_link_num))] +
                                        [Logical_topo_weight[t][k][i][j][x] for x in
                                         range(0, len(Logical_topo_weight[t][k][i][j]))])
                            # 更新 weight ，更新方法为在数组前加增加连接数目的 0,这是因为这部分连接带宽是空的
                        else:
                            # 若更新后该 OXC 在某 node 对之间的连接数没有增加
                            new_del_link_num = logical_topo[t][k][i][j] - update_logical_topo_try[t][k][i][j]
                            # 计算减少连接数目
                            update_logical_topo_weight[t][k][i][j] = \
                                [Logical_topo_weight[t][k][i][j][n] for n in range(int(new_del_link_num), len(
                                    Logical_topo_weight[t][k][i][j]))]
                            # 更新 weight ,更新方法为删除 weight 较小的连接，由于 weight 数组按升序排列，因此去掉前面的元素即可

        if index == 1:
            for t in range(0, inputs.group_num):
                for k in range(0, inputs.oxc_num_a_group):
                    del_topo_row, del_topo_col = np.where(update_logical_topo[t][k])
                    # 找到已更新逻辑子拓扑有连接的 node 对
                    del_update_logical_topo[t][k] = np.zeros([inputs.nodes_num, inputs.nodes_num])
                    for i in range(0, len(del_topo_row)):
                        links_tobe_add_topo[del_topo_row[i]][del_topo_col[i]] += 1
                        # 为这些有至少一条连接的 node 对删一条连接，以腾出端口，放入待增加拓扑中
                        del_update_logical_topo[t][k][del_topo_row[i]][del_topo_col[i]] = 1
                    del_update_logical_topo[t][k] = del_update_logical_topo[t][k].astype(int)
                    update_logical_topo[t][k] -= del_update_logical_topo[t][k]
                    # 更新当前逻辑拓扑，减去子拓扑中刚刚断开的连接

            links_tobe_add_topo -= update_delta_topo_delete
            links_tobe_add_topo[links_tobe_add_topo < 0] = 0

            links_tobe_add_topo += update_delta_topo_add

            links_tobe_add_topo, update_logical_topo, update_delta_topo_delete, use_ind = (
                sub_add_conns_v2.sub_add_conns_v2(inputs, update_logical_topo_weight, update_logical_topo,
                                                  update_delta_topo_delete, links_tobe_add_topo, use_ind,
                                                  del_update_logical_topo))

            index += 1

            if len(links_tobe_add_topo) == 0:
                break
        else:
            links_tobe_add_topo, update_logical_topo, update_delta_topo_delete, use_ind = (
                sub_add_conns_v2.sub_add_conns_v2(inputs, update_logical_topo_weight, update_logical_topo,
                                                  update_delta_topo_delete, links_tobe_add_topo, use_ind,
                                                  del_update_logical_topo))
            index += 1
            if len(links_tobe_add_topo) == 0:
                break

    return links_tobe_add_topo, update_logical_topo, update_delta_topo_delete
