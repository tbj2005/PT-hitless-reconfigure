# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06月26日
"""
import copy
import select_links
import numpy as np

import max_flow


def sub_add_conns_v2(inputs, update_logical_topo_weight, update_logical_topo, update_delta_topo_del,
                     links_tobe_add_topo, used_ind, del_update_logical_topo_all):
    mf = np.zeros([inputs.group_num, inputs.oxc_num_a_group])
    add_connections = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
    for t in range(0, inputs.group_num):
        for k in range(0, inputs.oxc_num_a_group):
            logical_topo_weight = np.zeros([inputs.nodes_num, inputs.nodes_num])
            for i in range(0, inputs.nodes_num):
                for j in range(0, inputs.nodes_num):
                    if len(update_logical_topo_weight[t][k][i][j]) == 0:
                        logical_topo_weight[i][j] = 0
                    else:
                        logical_topo_weight[i][j] = update_logical_topo_weight[t][k][i][j][0]

            update_logical_topo_kt = copy.deepcopy(update_logical_topo[t][k])
            rest_del_update_logical_topo = copy.deepcopy(update_logical_topo_kt)
            max_match_num = np.zeros(len(rest_del_update_logical_topo))
            free_ports_before_del = np.zeros(len(rest_del_update_logical_topo))
            for i_ind in range(0, len(rest_del_update_logical_topo)):
                max_match_num[i_ind] = inputs.physical_conn_oxc - np.sum(rest_del_update_logical_topo[i_ind, :])
                free_ports_before_del[i_ind] = inputs.physical_conn_oxc - np.sum(update_logical_topo_kt[i_ind, :])

            already_matched_nodes = []
            match_node = []
            for node_ind in range(0, inputs.nodes_num):
                already_matched_nodes = [node_ind] + already_matched_nodes
                match_cols = np.where(links_tobe_add_topo[node_ind, :])
                match_cols = match_cols[0]
                match_cols = [x for x in match_cols if x not in already_matched_nodes]
                match_cols = sorted(match_cols)
                print(match_cols)
                match_node.append([[match_cols[i], links_tobe_add_topo[node_ind, match_cols[i]]] for i in
                                   range(0, len(match_cols))])

            print(match_node, max_match_num)
            mf[t][k], add_connections[t][k] = max_flow.max_flow(inputs, match_node, max_match_num)

            if mf[t][k] != 0:
                mf[t][k], add_connections[t][k] = (
                    select_links.select_links(inputs, add_connections[t][k], links_tobe_add_topo, max_match_num))

            del_update_logical_topo = del_update_logical_topo_all[t][k]
            add_connections1_check = add_connections[t][k][:, 0:2]
            add_connections2_check = [[add_connections[t][k][n][1], add_connections[t][k][n][0]] for n in
                                      range(0, len(add_connections[t][k]))]
            rows_del, col_del = np.where(del_update_logical_topo)

