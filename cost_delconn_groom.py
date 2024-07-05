# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06约25日
"""
import copy
import time

import numpy as np
import Input_class


def cost_del_conn_groom(inputs, delta_topo, Logical_topo, method):
    max_links_InNodes = inputs.physical_conn_oxc
    delta_topo_delete_weight = delta_topo.delta_topo_delete_weight
    delta_topo_delete = delta_topo.delta_topo_delete
    delta_topo_add = delta_topo.delta_topo_add
    update_topo = Input_class.UP()
    total_cost = 0

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
        del_sub = []
        for i in range(0, len(sub_index_row)):
            if reshape_triu_delta_topo_add[sort_add_delta_topo_ind[i]] > 0:
                sub_index.append([sub_index_row[i], sub_index_col[i]])
            else:
                break
        for i in range(0, len(sub_index)):
            for j in range(0, len(row0)):
                if [sub_index[i][0], sub_index[i][1]] == [row0[j], col0[j]]:
                    del_sub.append(i)
                    break
        sub_index = [sub_index[i] for i in range(0, len(sub_index)) if i not in del_sub]
        for i in range(0, len(sub_index)):
            index_i_degree1_1 = np.sum(logical_topo[sub_index[i][0]])
            index_i_degree2_1 = np.sum(logical_topo[sub_index[i][1]])
            if max_links_InNodes - index_i_degree1_1 > 0:
                free_ports += [sub_index[i][0] for _ in range(0, int(max_links_InNodes - index_i_degree1_1))]
            if max_links_InNodes - index_i_degree2_1 > 0:
                free_ports += [sub_index[i][1] for _ in range(0, int(max_links_InNodes - index_i_degree2_1))]

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
        add_benefit = 0
        can_add_conns_InNodePair = np.zeros(len(sub_index))
        for i in range(0, len(sub_index)):
            index_i_degree1 = np.sum(update_logical_topo[sub_index[i][0]])
            index_i_degree2 = np.sum(update_logical_topo[sub_index[i][1]])
            max_add_conns_InNodePair = max_links_InNodes - max(index_i_degree1, index_i_degree2)
            require_add_conns_InNodePair = update_delta_add_topo[sub_index[i][0]][sub_index[i][1]]
            can_add_conns_InNodePair[i] = min(require_add_conns_InNodePair, max_add_conns_InNodePair)
            add_benefit += can_add_conns_InNodePair[i]

            update_logical_topo[sub_index[i][0]][sub_index[i][1]] += can_add_conns_InNodePair[i]
            update_logical_topo[sub_index[i][1]][sub_index[i][0]] += can_add_conns_InNodePair[i]
            update_delta_add_topo[sub_index[i][0]][sub_index[i][1]] = (delta_topo_add[sub_index[i][0]][sub_index[i][1]]
                                                                       - can_add_conns_InNodePair[i])
            update_delta_add_topo[sub_index[i][1]][sub_index[i][0]] = (delta_topo_add[sub_index[i][1]][sub_index[i][0]]
                                                                       - can_add_conns_InNodePair[i])
        can_add_conns_InNodePair = can_add_conns_InNodePair.astype(int)
        new_add_links = np.sum(can_add_conns_InNodePair)
        for i in range(0, len(sub_index)):
            if can_add_conns_InNodePair[i] > 0:
                value_in_AddNodePairs = np.tile([sub_index[i][0], sub_index[i][1]],
                                                can_add_conns_InNodePair[i])
                for j in range(0, 2 * can_add_conns_InNodePair[i]):
                    loc_free_ports = [k if value_in_AddNodePairs[j] == free_ports[k] else -1 for k in range(0, len(
                        free_ports))]
                    loc_free_ports = [k for k in loc_free_ports if k != -1]
                    if len(loc_free_ports) == 0:
                        loc_free_ports = -1
                    else:
                        loc_free_ports = min(loc_free_ports)
                    if loc_free_ports != -1:
                        free_ports[loc_free_ports] = -1
                    else:
                        row_indices, col_indices = np.where(del_index[:, 0:2] == value_in_AddNodePairs[j])
                        if len(row_indices) > 0:
                            min_row_index = np.argmin(del_index[row_indices, 2])
                            del_index[row_indices[min_row_index]][col_indices[min_row_index]] = -1

        update_delta_delete_topo = np.zeros([inputs.nodes_num, inputs.nodes_num])
        rows_with_zero, _ = np.where(del_index[:, 0:2] == -1)
        rows_with_zero = np.unique(np.sort(rows_with_zero))

        del_uv = del_index_init[rows_with_zero, 0:2]
        for i in range(0, len(rows_with_zero)):
            update_delta_delete_topo[del_uv[i][0]][del_uv[i][1]] = 1
        update_delta_delete_topo += update_delta_delete_topo.T
        update_delta_ReBack_topo = delta_topo_delete - update_delta_delete_topo
        update_delta_ReBack_topo = update_delta_ReBack_topo.astype(int)
        update_logical_topo += update_delta_ReBack_topo

        delete_topo_row, delete_topo_col = np.where(update_delta_ReBack_topo)
        update_delta_delete_ReBack_topo_wei = np.zeros([inputs.nodes_num, inputs.nodes_num])

        if len(delete_topo_row) > 0:
            for i in range(0, len(delete_topo_row)):
                update_delta_delete_ReBack_topo_wei[delete_topo_row[i]][delete_topo_col[i]] = (
                    delta_topo_delete_weight)[delete_topo_row[i]][delete_topo_col[i]]
        update_logical_topo_cap = logical_topo_cap - delta_topo_delete_weight + update_delta_delete_ReBack_topo_wei

        real_del_sub_index1, real_del_sub_index2 = np.where(update_delta_delete_topo)

        if np.sum(update_delta_delete_topo) > 0:
            if method == 1:
                delete_cost = sum([delta_topo_delete[real_del_sub_index1[k]][real_del_sub_index2[k]] for k in
                                   range(0, len(real_del_sub_index1))])
                total_cost = add_benefit - delete_cost
            if method == 2:
                delete_cost = sum([delta_topo_delete_weight[real_del_sub_index1[k]][real_del_sub_index2[k]] for k in
                                   range(0, len(real_del_sub_index1))])
                total_cost = add_benefit - delete_cost

            update_topo.update_logical_topo_cap = update_logical_topo_cap
            update_topo.update_logical_topo = update_logical_topo
            update_topo.update_delta_add_topo = update_delta_add_topo
            update_topo.update_delta_delete_topo_ed = update_delta_delete_topo
            update_topo.update_delta_topo_delete = delta_topo_delete - update_delta_delete_topo
        else:
            total_cost = - np.Inf
            update_topo.update_logical_topo_cap = logical_topo_cap
            update_topo.update_logical_topo = logical_topo
            update_topo.update_delta_add_topo = delta_topo_add
            update_topo.update_delta_delete_topo_ed = np.zeros([inputs.nodes_num, inputs.nodes_num])
            update_topo.update_delta_topo_delete = delta_topo_delete
            new_add_links = 0
    else:
        total_cost = - np.Inf
        update_topo.update_logical_topo_cap = logical_topo_cap
        update_topo.update_logical_topo = logical_topo
        update_topo.update_delta_add_topo = delta_topo_add
        update_topo.update_delta_delete_topo_ed = np.zeros([inputs.nodes_num, inputs.nodes_num])
        update_topo.update_delta_topo_delete = delta_topo_delete
        new_add_links = 0

    return total_cost, update_topo, new_add_links
