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

    row, col = np.where(np.triu(delta_topo_delete))
    # 找到删除连接的 node 对
    del_ele = 2 * sum([logical_topo[row[k]][col[k]] for k in range(0, len(row))])
    # 对这些 node 对的更新后逻辑拓扑连接求和

    free_ports = []

    if del_ele > 0:
        # 如果当前更新完的拓扑可以删除至少一条待删除连接
        triu_delta_topo_add = np.triu(delta_topo_add)
        reshape_triu_delta_topo_add = np.reshape(triu_delta_topo_add, (-1,), order='F')
        nonzero = np.count_nonzero(reshape_triu_delta_topo_add)
        sort_add_delta_topo_ind = np.argsort(reshape_triu_delta_topo_add)[::-1]
        sort_add_delta_topo_ind = sort_add_delta_topo_ind[0: nonzero]
        sub_index_col = sort_add_delta_topo_ind / inputs.nodes_num
        sub_index_col = sub_index_col.astype(int)
        sub_index_row = sort_add_delta_topo_ind % inputs.nodes_num
        # row0, col0 = np.where(triu_delta_topo_add == 0)
        # sub_index = []
        sub_index = [[sub_index_row[i], sub_index_col[i]] for i in range(0, len(sub_index_row))]
        # 找到还需要增加的连接的位置
        # del_sub = []
        """
        for i in range(0, len(sub_index_row)):
            if reshape_triu_delta_topo_add[sort_add_delta_topo_ind[i]] > 0:
                sub_index.append([sub_index_row[i], sub_index_col[i]])
            else:
                break
        """
        # for i in range(0, len(sub_index)):
        #     for j in range(0, len(row0)):
        #         if [sub_index[i][0], sub_index[i][1]] == [row0[j], col0[j]]:
        #             del_sub.append(i)
        #             break
        # sub_index = [sub_index[i] for i in range(0, len(sub_index)) if i not in del_sub]
        # 为待增加矩阵的 node 对 按照其待增加连接数目按从大到小排序
        add_links_ports = []
        for i in range(0, len(sub_index)):
            add_links_ports += [sub_index[i][0], sub_index[i][1]]
        add_links_ports = sorted(list(set(add_links_ports)))
        # 找到还需要增加连接的相关端口
        for i in range(0, len(add_links_ports)):
            # 遍历端口，计算节点度
            index_i_degree1_1 = np.sum(logical_topo[add_links_ports[i]])
            if max_links_InNodes - index_i_degree1_1 > 0:
                free_ports += [add_links_ports[i] for _ in range(0, int(max_links_InNodes - index_i_degree1_1))]
                # 每个 node 有多少剩余端口，在 free_ports里就会复制几次
        # for i in range(0, len(sub_index)):
        #     index_i_degree1_1 = np.sum(logical_topo[sub_index[i][0]])
        #     index_i_degree2_1 = np.sum(logical_topo[sub_index[i][1]])
        #     # 计算节点已使用端口数
        #     if max_links_InNodes - index_i_degree1_1 > 0:
        #         # 节点没用满，更新 free_ports 数组
        #         free_ports += [sub_index[i][0] for _ in range(0, int(max_links_InNodes - index_i_degree1_1))]
        #     if max_links_InNodes - index_i_degree2_1 > 0:
        #         free_ports += [sub_index[i][1] for _ in range(0, int(max_links_InNodes - index_i_degree2_1))]

        after_delete_topo = logical_topo - delta_topo_delete
        # 删掉连接后的逻辑拓扑
        after_delete_topo[after_delete_topo < 0] = 0
        # 如果删完连接后发现连接数为负数，那就不删了
        update_delta_add_topo = copy.deepcopy(delta_topo_add)
        update_logical_topo = copy.deepcopy(after_delete_topo)
        index_delete_topo_row, index_delete_topo_col = np.where(np.triu(delta_topo_delete))
        # 找出被删除连接位置
        del_index = np.zeros([len(index_delete_topo_row), 3])
        for i in range(0, len(index_delete_topo_row)):
            # 填充被删除连接位置和删除连接数目
            del_index[i][0] = index_delete_topo_row[i] + 0
            del_index[i][1] = index_delete_topo_col[i] + 0
            del_index[i][2] = delta_topo_delete[index_delete_topo_row[i]][index_delete_topo_col[i]]
        del_index = del_index.astype(int)
        del_index_init = copy.deepcopy(del_index)
        add_benefit = 0
        can_add_conns_InNodePair = np.zeros(len(sub_index))
        # 记录每一对可删除连接可以增加的连接数目
        for i in range(0, len(sub_index)):
            index_i_degree1 = np.sum(update_logical_topo[sub_index[i][0]])
            index_i_degree2 = np.sum(update_logical_topo[sub_index[i][1]])
            max_add_conns_InNodePair = max_links_InNodes - max(index_i_degree1, index_i_degree2)
            require_add_conns_InNodePair = update_delta_add_topo[sub_index[i][0]][sub_index[i][1]]
            can_add_conns_InNodePair[i] = min(require_add_conns_InNodePair, max_add_conns_InNodePair)
            # 更新可增加连接数目
            add_benefit += can_add_conns_InNodePair[i]

            update_logical_topo[sub_index[i][0]][sub_index[i][1]] += can_add_conns_InNodePair[i]
            update_logical_topo[sub_index[i][1]][sub_index[i][0]] += can_add_conns_InNodePair[i]
            # 更新拓扑
            update_delta_add_topo[sub_index[i][0]][sub_index[i][1]] = (delta_topo_add[sub_index[i][0]][sub_index[i][1]]
                                                                       - can_add_conns_InNodePair[i])
            update_delta_add_topo[sub_index[i][1]][sub_index[i][0]] = (
                    update_delta_add_topo[sub_index[i][0]][sub_index[i][1]] + 0)
        can_add_conns_InNodePair = can_add_conns_InNodePair.astype(int)
        new_add_links = np.sum(can_add_conns_InNodePair)
        # 计算可以增加的连接总数

        for i in range(0, len(sub_index)):
            if can_add_conns_InNodePair[i] > 0:
                value_in_AddNodePairs = []
                for k in range(0, can_add_conns_InNodePair[i]):
                    value_in_AddNodePairs += [sub_index[i][0], sub_index[i][1]]
                for j in range(0, 2 * can_add_conns_InNodePair[i]):
                    loc_free_ports = [k for k in range(0, len(free_ports)) if value_in_AddNodePairs[j] == free_ports[k]]
                    if len(loc_free_ports) != 0:
                        for loc in range(0, len(loc_free_ports)):
                            free_ports[loc] = -1
                            # 修改 port 使用情况
                    else:
                        # loc_free_ports = min(loc_free_ports)
                        # if loc_free_ports != -1:
                        #     for loc in range(0, len(free_ports)):
                        #         free_ports[loc] = -1
                        # else:
                        row_indices, col_indices \
                            = np.where(np.array([del_index[k][0:2] for k in range(0, len(
                                    del_index))]) == value_in_AddNodePairs[j])
                        if len(row_indices) > 0:
                            min_row_index = (
                                np.argmin(np.array([del_index[row_indices[k]][2] for k in range(0, len(row_indices))])))
                            del_index[row_indices[min_row_index]][col_indices[min_row_index]] = -1

        update_delta_delete_topo = np.zeros([inputs.nodes_num, inputs.nodes_num])
        rows_with_zero, _ = np.where(np.array([del_index[k][0:2] for k in range(0, len(del_index))]) == -1)
        rows_with_zero = np.unique(np.sort(rows_with_zero))
        del_uv = [del_index_init[rows_with_zero[k]][0:2] for k in range(0, len(rows_with_zero))]
        for i in range(0, len(rows_with_zero)):
            update_delta_delete_topo[del_uv[i][0]][del_uv[i][1]] = 1
        update_delta_delete_topo += update_delta_delete_topo.T
        update_delta_ReBack_topo = delta_topo_delete - update_delta_delete_topo
        update_delta_ReBack_topo = update_delta_ReBack_topo.astype(int)
        update_logical_topo += update_delta_ReBack_topo

        delete_topo_row, delete_topo_col = np.where(np.triu(update_delta_ReBack_topo))
        update_delta_delete_ReBack_topo_wei = np.zeros([inputs.nodes_num, inputs.nodes_num])

        if len(delete_topo_row) > 0:
            for i in range(0, len(delete_topo_row)):
                update_delta_delete_ReBack_topo_wei[delete_topo_row[i]][delete_topo_col[i]] = (
                    delta_topo_delete_weight)[delete_topo_row[i]][delete_topo_col[i]]
                update_delta_delete_ReBack_topo_wei[delete_topo_col[i]][delete_topo_row[i]] = (
                        update_delta_delete_ReBack_topo_wei[delete_topo_row[i]][delete_topo_col[i]] + 0)
        update_logical_topo_cap = logical_topo_cap - delta_topo_delete_weight + update_delta_delete_ReBack_topo_wei

        real_del_sub_index1, real_del_sub_index2 = np.where(np.triu(update_delta_delete_topo))

        if np.sum(update_delta_delete_topo) > 0:
            if method == 1:
                delete_cost = 2 * sum([delta_topo_delete[real_del_sub_index1[k]][real_del_sub_index2[k]] for k in
                                   range(0, len(real_del_sub_index1))])
                total_cost = add_benefit - delete_cost
            if method == 2:
                delete_cost = 2 * sum([delta_topo_delete_weight[real_del_sub_index1[k]][real_del_sub_index2[k]] for k in
                                   range(0, len(real_del_sub_index1))])
                total_cost = add_benefit - delete_cost

            update_topo.update_logical_topo_cap = copy.deepcopy(update_logical_topo_cap)
            update_topo.update_logical_topo = copy.deepcopy(update_logical_topo)
            update_topo.update_delta_add_topo = copy.deepcopy(update_delta_add_topo)
            update_topo.update_delta_delete_topo_ed = copy.deepcopy(update_delta_delete_topo)
            update_topo.update_delta_topo_delete = delta_topo_delete - update_delta_delete_topo
        else:
            total_cost = - np.Inf
            update_topo.update_logical_topo_cap = copy.deepcopy(logical_topo_cap)
            update_topo.update_logical_topo = copy.deepcopy(logical_topo)
            update_topo.update_delta_add_topo = copy.deepcopy(delta_topo_add)
            update_topo.update_delta_delete_topo_ed = np.zeros([inputs.nodes_num, inputs.nodes_num])
            update_topo.update_delta_topo_delete = copy.deepcopy(delta_topo_delete)
            new_add_links = 0
    else:
        total_cost = - np.Inf
        update_topo.update_logical_topo_cap = copy.deepcopy(logical_topo_cap)
        update_topo.update_logical_topo = copy.deepcopy(logical_topo)
        update_topo.update_delta_add_topo = copy.deepcopy(delta_topo_add)
        update_topo.update_delta_delete_topo_ed = np.zeros([inputs.nodes_num, inputs.nodes_num])
        update_topo.update_delta_topo_delete = copy.deepcopy(delta_topo_delete)
        new_add_links = 0

    return total_cost, update_topo, new_add_links
