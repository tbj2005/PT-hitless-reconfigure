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
                            new_add_link_num = update_logical_topo_try[t][k][i][j] - logical_topo[t][k][i][j]
                            update_logical_topo_weight[t][k][i][j] = ([0 for _ in range(0, int(new_add_link_num))] +
                                                                      Logical_topo_weight[t][k][i][j])
                        else:
                            new_del_link_num = logical_topo[t][k][i][j] - update_logical_topo_try[t][k][i][j]
                            update_logical_topo_weight[t][k][i][j] = \
                                [Logical_topo_weight[t][k][i][j][n] for n in range(int(new_del_link_num), len(
                                    Logical_topo_weight[t][k][i][j]))]

        if index == 1:
            for t in range(0, inputs.group_num):
                for k in range(0, inputs.oxc_num_a_group):
                    del_topo_row, del_topo_col = np.where(update_logical_topo[t][k])
                    del_update_logical_topo[t][k] = np.zeros([inputs.nodes_num, inputs.nodes_num])
                    for i in range(0, len(del_topo_row)):
                        links_tobe_add_topo[del_topo_row[i]][del_topo_col[i]] += 1
                        del_update_logical_topo[t][k][del_topo_row[i]][del_topo_col[i]] = 1
                    del_update_logical_topo[t][k] = del_update_logical_topo[t][k].astype(int)
                    update_logical_topo[t][k] -= del_update_logical_topo[t][k]

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
