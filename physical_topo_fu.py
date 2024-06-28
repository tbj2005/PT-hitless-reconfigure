# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06约24日
"""
import copy
import numpy as np
import cost_delconn_groom
import re_add_conn
import Input_class


# 该函数用于计算目标物理拓扑


def physical_topo_fu(inputs, delta_topology, logical_topo_traffic, logical_topo, logical_topo_cap):
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
    for t in range(0, inputs.group_num):
        for k in range(0, inputs.oxc_num_a_group):
            triu_update_delta_topo_add = np.triu(update_delta_topo_add)
            reshape_triu_update_delta_topo_add = np.reshape(triu_update_delta_topo_add, (-1,), order='F')
            sort_add_delta_topo_ind = np.argsort(reshape_triu_update_delta_topo_add)[::-1]
            sub_index_col = sort_add_delta_topo_ind / inputs.nodes_num
            sub_index_col = sub_index_col.astype(int)
            sub_index_row = sort_add_delta_topo_ind % inputs.nodes_num
            row0, col0 = np.where(triu_update_delta_topo_add == 0)
            sub_index = []
            for i in range(0, len(sub_index_row)):
                sub_index.append([sub_index_row[i], sub_index_col[i]])
            for i in range(0, len(sub_index_row)):
                for j in range(0, len(row0)):
                    if [sub_index_row[i], sub_index_col[i]] == [row0[j], col0[j]]:
                        sub_index.remove([row0[j], col0[j]])
            benefit = 0
            for i in range(0, len(sub_index)):
                index_i_degree1 = np.sum(update_logical_topo[t][k][sub_index[i][0]])
                index_i_degree2 = np.sum(update_logical_topo[t][k][sub_index[i][1]])
                max_add_conns_InNodePair = inputs.physical_conn_oxc - max(index_i_degree1, index_i_degree2)
                require_add_conns_InNodePair = update_delta_topo_add[sub_index[i][0]][sub_index[i][1]]
                can_add_conns_InNodePair = min(require_add_conns_InNodePair, max_add_conns_InNodePair)
                update_logical_topo[t][k][sub_index[i][0]][sub_index[i][1]] = \
                    can_add_conns_InNodePair + update_logical_topo[t][k][sub_index[i][0]][sub_index[i][1]]
                update_logical_topo[t][k][sub_index[i][1]][sub_index[i][0]] = (
                    update_logical_topo)[t][k][sub_index[i][0]][sub_index[i][1]]
                update_logical_topo_cap[t][k][sub_index[i][0]][sub_index[i][1]] = \
                    (can_add_conns_InNodePair * inputs.connection_cap +
                     update_logical_topo[t][k][sub_index[i][0]][sub_index[i][1]] - can_add_conns_InNodePair)
                update_logical_topo_cap[t][k][sub_index[i][1]][sub_index[i][0]] = (
                    update_logical_topo_cap)[t][k][sub_index[i][0]][sub_index[i][1]]
                update_delta_topo_add[sub_index[i][0]][sub_index[i][1]] -= can_add_conns_InNodePair
                update_delta_topo_add[sub_index[i][1]][sub_index[i][0]] -= can_add_conns_InNodePair
                benefit += can_add_conns_InNodePair
            whole_logical_topo += update_logical_topo[t][k]
            whole_logical_topo_cap += update_logical_topo_cap[t][k]

    Logical_topo_weight = (
        np.empty([inputs.group_num, inputs.oxc_num_a_group, inputs.nodes_num, inputs.nodes_num], dtype=object))
    update_delta_topo_delete_tk = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
    deleted_links_all = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
    total_benefit = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
    new_add_links = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)

    for t in range(0, inputs.group_num):
        for k in range(0, inputs.oxc_num_a_group):
            logical_topo_traffic[t][k] += logical_topo_traffic[t][k].T
            rows, cols = np.where(logical_topo_traffic[t][k])
            for u in range(0, inputs.nodes_num):
                for v in range(0, inputs.nodes_num):
                    Logical_topo_weight[t][k][u][v] = np.zeros(logical_topo[t][k][u][v])
            for w_ind in range(0, len(rows)):
                w_required_LinkNum = logical_topo_traffic[t][k][rows[w_ind]][cols[w_ind]] / inputs.connection_cap
                res_traffic = logical_topo_traffic[t][k][rows[w_ind]][cols[w_ind]] % inputs.connection_cap
                w_required_LinkNum_floor = int(np.floor(w_required_LinkNum))
                actual_LinkSum = update_logical_topo[t][k][rows[w_ind]][cols[w_ind]]
                if res_traffic == 0:
                    if actual_LinkSum > w_required_LinkNum_floor:
                        Logical_topo_weight[t][k][rows[w_ind]][cols[w_ind]] = (
                                [0 for _ in range(0, actual_LinkSum - w_required_LinkNum_floor)] +
                                [inputs.connection_cap * (i + 1) for i in range(0, w_required_LinkNum_floor)])
                    else:
                        Logical_topo_weight[t][k][rows[w_ind]][cols[w_ind]] = (
                            [inputs.connection_cap * (i + 1) for i in range(0, w_required_LinkNum_floor)])
                else:
                    if actual_LinkSum == w_required_LinkNum_floor + 1:
                        Logical_topo_weight[t][k][rows[w_ind]][cols[w_ind]] = (
                                res_traffic + [inputs.connection_cap * (i + 1) for i in
                                               range(0, w_required_LinkNum_floor)])
                    else:
                        Logical_topo_weight[t][k][rows[w_ind]][cols[w_ind]] = (
                                [0 for _ in range(0, actual_LinkSum - w_required_LinkNum_floor - 1)] + [res_traffic] +
                                [inputs.connection_cap * (i + 1) for i in range(0, w_required_LinkNum_floor)])
            for u in range(0, inputs.nodes_num):
                for v in range(0, inputs.nodes_num):
                    if len(Logical_topo_weight[t][k][u][v]) == 0:
                        Logical_topo_weight[t][k][u][v] = [0]
            update_delta_topo_delete_tk[t][k] = np.zeros([inputs.nodes_num, inputs.nodes_num])
            deleted_links_all[t][k] = np.zeros([inputs.nodes_num, inputs.nodes_num])

    update_delta_topo_delete = copy.deepcopy(delta_topo_delete)

    while np.sum(update_delta_topo_add) > 0:
        update_topo = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
        deleted_links_all_1 = (
            np.zeros([inputs.group_num, inputs.oxc_num_a_group, inputs.nodes_num, inputs.nodes_num], dtype=int))
        for t in range(0, inputs.group_num):
            for k in range(0, inputs.oxc_num_a_group):
                InterMid_delta_topo_may = copy.deepcopy(update_delta_topo_delete)
                InterMid_delta_topo_may[InterMid_delta_topo_may > 0] = 1
                row_del, col_del = np.where(InterMid_delta_topo_may)
                InterMid_delta_topo2 = np.zeros([inputs.nodes_num, inputs.nodes_num], dtype=int)
                for we in range(0, len(row_del)):
                    if update_logical_topo[t][k][row_del[we]][col_del[we]] > 0:
                        InterMid_delta_topo2[row_del[we]][col_del[we]] = 1
                row_del1, col_del1 = np.where(InterMid_delta_topo2)
                row_del1 = row_del1.astype(int)
                col_del1 = col_del1.astype(int)

                if np.sum(InterMid_delta_topo2) == 0:
                    total_benefit[t][k] = - np.Inf
                    new_add_links[t][k] = 0
                else:
                    delta_topo_delete_weight = copy.deepcopy(InterMid_delta_topo2)
                    deleted_links_all_1[t][k] = deleted_links_all[t][k] + InterMid_delta_topo2

                    for we_in in range(0, len(row_del1)):
                        deleted_links_all_2 = copy.deepcopy(deleted_links_all_1[t][k])
                        delta_topo_delete_weight[row_del1[we_in]][col_del1[we_in]] = Logical_topo_weight[t][k][
                            row_del1[we_in]][col_del1[we_in]][deleted_links_all_2[row_del1[we_in]][col_del1[we_in]] - 1]

                    delta_topo = Input_class.DeltaTopology()
                    delta_topo.delta_topo_delete_weight = copy.deepcopy(delta_topo_delete_weight)
                    delta_topo.delta_topo_delete = copy.deepcopy(InterMid_delta_topo2)
                    delta_topo.delta_topo_add = copy.deepcopy(update_delta_topo_add)
                    Logical_topo = Input_class.LP()
                    Logical_topo.logical_topo_cap = copy.deepcopy(update_logical_topo_cap[t][k])
                    Logical_topo.logical_topo = update_logical_topo[t][k]

                    total_benefit[t][k], update_topo[t][k], new_add_links[t][k] = (
                        cost_delconn_groom.cost_del_conn_groom(inputs, delta_topo, Logical_topo, method))

        b_check = 0
        if np.sum(new_add_links) == 0:
            while np.sum(update_delta_topo_add) > 0:
                b_check += 1
                update_delta_topo_add, update_logical_topo, update_delta_topo_delete = (
                    re_add_conn.re_add_conns(inputs, logical_topo, Logical_topo_weight, update_delta_topo_add,
                                             update_logical_topo, update_delta_topo_delete))
        else:
            min_total_benefit = np.max(total_benefit)
            min_row, min_col = np.where(total_benefit == min_total_benefit)
            update_logical_topo[min_row[0]][min_col[0]] = update_topo[min_row[0]][min_col[0]].update_logical_topo
            update_logical_topo_cap[min_row[0]][min_col[0]] = update_topo[min_row[0]][min_col[0]].update_delta_add_topo
            update_delta_topo_del_ed = update_topo[min_row[0]][min_col[0]].update_delta_delete_topo_ed
            update_delta_topo_add = update_topo[min_row[0]][min_col[0]].update_delta_add_topo
            update_delta_topo_del_ed = update_delta_topo_del_ed.astype(int)
            update_delta_topo_delete -= update_delta_topo_del_ed
            update_delta_topo_delete_tk[min_row[0]][min_col[0]] = update_delta_topo_del_ed
            deleted_links_all[min_row[0]][min_col[0]] += update_delta_topo_delete_tk[min_row[0]][min_col[0]]

    return update_logical_topo
