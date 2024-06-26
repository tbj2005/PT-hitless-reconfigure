# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06约25日
"""
import copy

import numpy as np


def cost_del_conn_groom(inputs, delta_topo, Logical_topo, method, traffic_distr):
    max_links_InNodes = inputs.physical_conn_oxc
    delta_topo_delete_weight = delta_topo.delta_topo_delete_weight
    delta_topo_delete = delta_topo.delta_topo_delete
    delta_topo_add = delta_topo.delta_topo_add

    if method == 3:
        print("************************")

    logical_topo_cap = Logical_topo.logical_topo_cap
    logical_topo = Logical_topo.logical_topo

    row, col = np.where(delta_topo_delete)
    del_ele = sum([logical_topo[row[k]][col[k]] for k in range(0, len(row))])

    free_ports = []

    if del_ele > 0:
        triu_delta_topo_add = np.triu(delta_topo_add)
        reshape_triu_delta_topo_add = np.reshape(triu_delta_topo_add, (-1,), order='F')
        sort_add_delta_topo_ind = np.argsort(reshape_triu_delta_topo_add)[::-1]
        sub_index_col = sort_add_delta_topo_ind / inputs.nodes_num
        sub_index_col = sub_index_col.astype(int)
        sub_index_row = sort_add_delta_topo_ind % inputs.nodes_num
        row0, col0 = np.where(triu_delta_topo_add == 0)
        sub_index = []
        for i in range(0, len(sub_index_row)):
            sub_index.append([sub_index_row[i], sub_index_col[i]])
        for i in range(0, len(sub_index_row)):
            for j in range(0, len(row0)):
                if [sub_index_row[i], sub_index_col[i]] == [row0[j], col0[j]]:
                    sub_index.remove([row0[j], col0[j]])
        for i in range(0, len(sub_index)):
            index_i_degree1_1 = np.sum(logical_topo[sub_index[i][0]])
            index_i_degree2_1 = np.sum(logical_topo[sub_index[i][1]])
            if max_links_InNodes - index_i_degree1_1 > 0:
                free_ports += [sub_index[i][0] for _ in range(0, max_links_InNodes - index_i_degree1_1)]
            if max_links_InNodes - index_i_degree2_1 > 0:
                free_ports += [sub_index[i][1] for _ in range(0, max_links_InNodes - index_i_degree2_1)]

        after_delete_topo = logical_topo - delta_topo_delete
        after_delete_topo[after_delete_topo < 0] = 0
        update_delta_add_topo = copy.deepcopy(delta_topo_add)
        update_logical_topo = copy.deepcopy(after_delete_topo)

        index_delete_topo_row, index_delete_topo_col = np.where(np.triu(delta_topo_delete))
        del_index = np.zeros([len(index_delete_topo_row), 3])
        for i in range(0, len(index_delete_topo_row)):
            del_index[i] = np.array([index_delete_topo_row[i], index_delete_topo_col[i], delta_topo_delete[
                index_delete_topo_row[i]][index_delete_topo_col[i]]])
        del_index = del_index.astype(int)
        del_index_init = copy.deepcopy(del_index)
        add_benifit = 0
        can_add_conns_InNodePair = np.zeros(len(sub_index))
        for i in range(0, len(sub_index)):
            index_i_degree1 = np.sum(update_logical_topo[sub_index[i][0]])
            index_i_degree2 = np.sum(update_logical_topo[sub_index[i][1]])
            max_add_conns_InNodePair = max_links_InNodes - max(index_i_degree1, index_i_degree2)
            require_add_conns_InNodePair = update_delta_add_topo[sub_index[i][0]][sub_index[i][1]]
            can_add_conns_InNodePair[i] = min(require_add_conns_InNodePair, max_add_conns_InNodePair)
            add_benifit += can_add_conns_InNodePair[i]

            update_logical_topo[sub_index[i][0]][sub_index[i][1]] += can_add_conns_InNodePair[i]
            update_logical_topo[sub_index[i][1]][sub_index[i][0]] += can_add_conns_InNodePair[i]
            update_delta_add_topo[sub_index[i][0]][sub_index[i][1]] = (delta_topo_add[sub_index[i][0]][sub_index[i][1]]
                                                                       - can_add_conns_InNodePair[i])
            update_delta_add_topo[sub_index[i][1]][sub_index[i][0]] = (delta_topo_add[sub_index[i][1]][sub_index[i][0]]
                                                                       - can_add_conns_InNodePair[i])
        new_add_links = np.sum(can_add_conns_InNodePair)

        for i in range(0, len(sub_index)):
            if can_add_conns_InNodePair[i] > 0:
                value_in_AddNodePairs = np.tile([sub_index[i][0], sub_index[i][1]],
                                                (1, can_add_conns_InNodePair[i]))
