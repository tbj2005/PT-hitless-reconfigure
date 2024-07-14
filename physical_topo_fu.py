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


def physical_topo_fu(inputs, delta_topology, logical_topo_traffic, logical_topo, logical_topo_cap, max_check):
    method = inputs.method
    delta_topo_add = copy.deepcopy(delta_topology)
    delta_topo_delete = copy.deepcopy(delta_topology)
    delta_topo_add[delta_topo_add < 0] = 0
    delta_topo_delete[delta_topo_delete > 0] = 0
    delta_topo_delete *= -1
    update_check_flag = 0

    whole_logical_topo = np.zeros([inputs.nodes_num, inputs.nodes_num])
    whole_logical_topo_cap = whole_logical_topo * inputs.connection_cap
    update_delta_topo_add = copy.deepcopy(delta_topo_add)
    update_logical_topo = copy.deepcopy(logical_topo)
    update_logical_topo_cap = copy.deepcopy(logical_topo_cap)
    # 观察是否可以不移除待移除连接，直接增加待增加连接
    for t in range(0, inputs.group_num):
        for k in range(0, inputs.oxc_num_a_group):
            triu_update_delta_topo_add = np.triu(update_delta_topo_add)
            reshape_triu_update_delta_topo_add = np.reshape(triu_update_delta_topo_add, (-1,), order='F')
            sort_add_delta_topo_ind = np.argsort(reshape_triu_update_delta_topo_add)[::-1]
            sub_index_col = sort_add_delta_topo_ind / inputs.nodes_num
            sub_index_col = sub_index_col.astype(int)
            sub_index_row = sort_add_delta_topo_ind % inputs.nodes_num
            row0, col0 = np.where(triu_update_delta_topo_add == 0)
            # 按增加连接数从大到小为 node 对排序,在这里，排序与 matlab 不同，但都是正确的
            sub_index = []
            for i in range(0, len(sub_index_row)):
                if reshape_triu_update_delta_topo_add[sort_add_delta_topo_ind[i]] > 0:
                    sub_index.append([sub_index_row[i], sub_index_col[i]])
                else:
                    break
            del_sub = []
            for i in range(0, len(sub_index)):
                for j in range(0, len(row0)):
                    if [sub_index[i][0], sub_index[i][1]] == [row0[j], col0[j]]:
                        del_sub.append(i)
                        break
            sub_index = [sub_index[i] for i in range(0, len(sub_index)) if i not in del_sub]
            # 除去所有不需要增加连接的 node 对
            benefit = 0
            for i in range(0, len(sub_index)):
                index_i_degree1 = np.sum(update_logical_topo[t][k][sub_index[i][0]])
                index_i_degree2 = np.sum(update_logical_topo[t][k][sub_index[i][1]])
                max_add_conns_InNodePair = inputs.physical_conn_oxc - max(index_i_degree1, index_i_degree2)
                # 计算 node 对间是否可以增加连接
                require_add_conns_InNodePair = update_delta_topo_add[sub_index[i][0]][sub_index[i][1]]
                # 计算 node 对间的增加连接需求
                can_add_conns_InNodePair = min(require_add_conns_InNodePair, max_add_conns_InNodePair)
                # 取可增连接和需求增加数最小值，并直接在该 node 对间加连接
                update_logical_topo[t][k][sub_index[i][0]][sub_index[i][1]] = \
                    can_add_conns_InNodePair + update_logical_topo[t][k][sub_index[i][0]][sub_index[i][1]]
                update_logical_topo[t][k][sub_index[i][1]][sub_index[i][0]] = (
                    update_logical_topo)[t][k][sub_index[i][0]][sub_index[i][1] + 0]
                update_logical_topo_cap[t][k][sub_index[i][0]][sub_index[i][1]] = \
                    (inputs.connection_cap * update_logical_topo[t][k][sub_index[i][0]][sub_index[i][1]] -
                     logical_topo_traffic[t][k][sub_index[i][0]][sub_index[i][1]] -
                     logical_topo_traffic[t][k][sub_index[i][1]][sub_index[i][0]])
                update_logical_topo_cap[t][k][sub_index[i][1]][sub_index[i][0]] = (
                    update_logical_topo_cap)[t][k][sub_index[i][0]][sub_index[i][1] + 0]
                # 重新计算加连接后的带宽容量，即连接 * 连接带宽
                update_delta_topo_add[sub_index[i][0]][sub_index[i][1]] -= can_add_conns_InNodePair
                update_delta_topo_add[sub_index[i][1]][sub_index[i][0]] -= can_add_conns_InNodePair
                # 更新需增加的带宽矩阵，将增加的连接从该矩阵移除
                # 更新输出逻辑拓扑及其容量
                benefit += can_add_conns_InNodePair
            whole_logical_topo += update_logical_topo[t][k]
            whole_logical_topo_cap += update_logical_topo_cap[t][k]
            # 更新增加该部分连接后的逻辑拓扑和带宽

    Logical_topo_weight = (
        np.empty([inputs.group_num, inputs.oxc_num_a_group, inputs.nodes_num, inputs.nodes_num], dtype=object))
    update_delta_topo_delete_tk = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
    deleted_links_all = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
    total_benefit = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
    new_add_links = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)

    # 当可以直接增线的连接都处理完，需要考虑删除待删除连接，腾出端口后增加待增加连接
    for t in range(0, inputs.group_num):
        for k in range(0, inputs.oxc_num_a_group):
            logical_topo_traffic[t][k] += logical_topo_traffic[t][k].T
            rows, cols = np.where(logical_topo_traffic[t][k])
            # 找出流量相关 node
            for u in range(0, inputs.nodes_num):
                for v in range(0, inputs.nodes_num):
                    Logical_topo_weight[t][k][u][v] = np.zeros(int(logical_topo[t][k][u][v]))
                    # 初始化 weight，每个子拓扑里，任意 node 对的元素是一个长为初始拓扑在这个子拓扑 node 对间的连接数的零数组
                    # 也就是说每条连接都没有被使用
            for w_ind in range(0, len(rows)):
                w_required_LinkNum = logical_topo_traffic[t][k][rows[w_ind]][cols[w_ind]] / inputs.connection_cap
                # 计算流量需要的连接数目
                res_traffic = logical_topo_traffic[t][k][rows[w_ind]][cols[w_ind]] % inputs.connection_cap
                # 流量是否可以将这些连接完全占用，求余数
                w_required_LinkNum_floor = int(np.floor(w_required_LinkNum))
                # 需要连接数向下取整，即用满连接
                actual_LinkSum = update_logical_topo[t][k][rows[w_ind]][cols[w_ind]] + 0
                # 当前连接数目由已更新逻辑拓扑矩阵求得
                if res_traffic == 0:
                    # 若流量需求是连接带宽的整数倍，此时向下取整还是自己
                    if actual_LinkSum > w_required_LinkNum_floor:
                        # 若现有连接足够使用
                        Logical_topo_weight[t][k][rows[w_ind]][cols[w_ind]] = (
                                [0 for _ in range(0, int(actual_LinkSum - w_required_LinkNum_floor))] +
                                [inputs.connection_cap * (i + 1) for i in range(0, int(w_required_LinkNum_floor))])
                        # 更新此时的 weight 为[0 * 未使用的连接， i * 使用连接]
                    else:
                        # 若现有连接不够用，说明还得加连接，相等也被划进此类，这是因为放哪里都是一样的
                        Logical_topo_weight[t][k][rows[w_ind]][cols[w_ind]] = (
                            [inputs.connection_cap * (i + 1) for i in range(0, int(w_required_LinkNum_floor))])
                        # 更新此时的 weight 为[i * 使用连接]
                else:
                    # 若流量需求不是带宽的整数倍
                    if actual_LinkSum <= w_required_LinkNum_floor + 1:
                        # 现有连接刚好满足要求或无法满足要求
                        Logical_topo_weight[t][k][rows[w_ind]][cols[w_ind]] = (
                                [res_traffic] + [inputs.connection_cap * (i + 1) for i in
                                                 range(0, int(w_required_LinkNum_floor))])
                        # 更新此时的 weight 为[带宽余数， i * 用满连接]
                    else:
                        # 现有带宽可以满足要求且会有空连接剩余
                        Logical_topo_weight[t][k][rows[w_ind]][cols[w_ind]] = (
                                [0 for _ in range(0, int(actual_LinkSum - w_required_LinkNum_floor - 1))] +
                                [res_traffic] +
                                [inputs.connection_cap * (i + 1) for i in range(0, int(w_required_LinkNum_floor))])
                        # 更新此时的 weight 为[0 * 未使用的连接， 带宽余数， i * 用满连接]
            """
            for u in range(0, inputs.nodes_num):
                for v in range(0, inputs.nodes_num):
                    if len(Logical_topo_weight[t][k][u][v]) == 0:
                        # 初始逻辑拓扑为0，将 weight 此时的值置为 [0]
                        Logical_topo_weight[t][k][u][v] = [0]
            """
            update_delta_topo_delete_tk[t][k] = np.zeros([inputs.nodes_num, inputs.nodes_num])
            deleted_links_all[t][k] = np.zeros([inputs.nodes_num, inputs.nodes_num])
            # 存放已删除连接

    update_delta_topo_delete = copy.deepcopy(delta_topo_delete)

    while np.sum(update_delta_topo_add) > 0:
        # 循环增加连接，直到待增加连接都加进去为止
        update_topo = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
        deleted_links_all_1 = (
            np.zeros([inputs.group_num, inputs.oxc_num_a_group, inputs.nodes_num, inputs.nodes_num], dtype=int))
        for t in range(0, inputs.group_num):
            for k in range(0, inputs.oxc_num_a_group):
                InterMid_delta_topo_may = copy.deepcopy(update_delta_topo_delete)
                InterMid_delta_topo_may[InterMid_delta_topo_may > 0] = 1
                row_del, col_del = np.where(InterMid_delta_topo_may)
                # 找到待删除连接相关 node
                InterMid_delta_topo2 = np.zeros([inputs.nodes_num, inputs.nodes_num], dtype=int)
                for we in range(0, len(row_del)):
                    # 遍历所有相关 node
                    if update_logical_topo[t][k][row_del[we]][col_del[we]] > 0:
                        # 若当前子拓扑有连接可删，为其删除一条连接
                        InterMid_delta_topo2[row_del[we]][col_del[we]] = 1
                row_del1, col_del1 = np.where(InterMid_delta_topo2)
                row_del1 = row_del1.astype(int)
                col_del1 = col_del1.astype(int)
                # 找到该轮删除连接的 node 对
                if np.sum(InterMid_delta_topo2) == 0:
                    # 如果这个子拓扑没有能删的连接，把 benefit 置为负无穷，可增加新连接置为0
                    total_benefit[t][k] = - np.Inf
                    new_add_links[t][k] = 0
                else:
                    # 如果这个子拓扑有能删的连接
                    delta_topo_delete_weight = copy.deepcopy(InterMid_delta_topo2)
                    deleted_links_all_1[t][k] = deleted_links_all[t][k] + InterMid_delta_topo2
                    # 更新删除一条连接后的连接删除矩阵
                    for we_in in range(0, len(row_del1)):
                        deleted_links_all_2 = copy.deepcopy(deleted_links_all_1[t][k])
                        delta_topo_delete_weight[row_del1[we_in]][col_del1[we_in]] = Logical_topo_weight[t][k][
                            row_del1[we_in]][col_del1[we_in]][deleted_links_all_2[row_del1[we_in]][col_del1[we_in]] - 1]
                        # 删除连接权重更新，最后一个索引表示增加删除的连接的连接索引
                    delta_topo = Input_class.DeltaTopology()
                    delta_topo.delta_topo_delete_weight = copy.deepcopy(delta_topo_delete_weight)
                    # 删除连接权重
                    delta_topo.delta_topo_delete = copy.deepcopy(InterMid_delta_topo2)
                    # 该阶段删除的连接矩阵
                    delta_topo.delta_topo_add = copy.deepcopy(update_delta_topo_add)
                    # 待增加连接矩阵
                    Logical_topo = Input_class.LP()
                    Logical_topo.logical_topo_cap = copy.deepcopy(update_logical_topo_cap[t][k])
                    # 更新连接后的容量
                    Logical_topo.logical_topo = copy.deepcopy(update_logical_topo[t][k])
                    # 更新连接后的连接矩阵
                    total_benefit[t][k], update_topo[t][k], new_add_links[t][k] = (
                        cost_delconn_groom.cost_del_conn_groom(inputs, delta_topo, Logical_topo, method))
                    # 计算 metric 和每个子拓扑的重构方案

        b_check = 0
        if np.sum(new_add_links) == 0:
            # 如果每个子拓扑都不能再通过删除待删除连接以增加待增加连接了，但仍然还存在待增加连接，此时进入打断重连
            add_value = np.Inf
            update_logical_topo_min = np.zeros([inputs.nodes_num, inputs.nodes_num])
            while np.sum(update_delta_topo_add) > 0:
                # 循环打乱重连，直到所有待增加连接全部增加
                b_check += 1
                if add_value > np.sum(update_delta_topo_add):
                    add_value = np.sum(update_delta_topo_add) + 0
                    update_logical_topo_min = copy.deepcopy(update_logical_topo)
                    # 找到增加连接最大的重连方案，并输出更新后逻辑拓扑
                if b_check == max_check:
                    # 到达最大重连次数，放弃打断重连并输出
                    update_check_flag = 1
                    return update_logical_topo_min, update_check_flag
                print(b_check)
                update_delta_topo_add, update_logical_topo, update_delta_topo_delete = (
                    re_add_conn.re_add_conns(inputs, logical_topo, Logical_topo_weight, update_delta_topo_add,
                                             update_logical_topo, update_delta_topo_delete))
        else:
            # 若删除链接后可以再增加待增加连接
            min_total_benefit = np.max(total_benefit)
            min_row, min_col = np.where(total_benefit == min_total_benefit)
            # 找到权重最大的子拓扑
            update_logical_topo[min_row[0]][min_col[0]] = (
                copy.deepcopy(update_topo[min_row[0]][min_col[0]].update_logical_topo))
            # 按计划更新该子拓扑的逻辑拓扑
            update_logical_topo_cap[min_row[0]][min_col[0]] = (
                copy.deepcopy(update_topo[min_row[0]][min_col[0]].update_delta_add_topo))
            # 更新子拓扑带宽矩阵
            update_delta_topo_del_ed = (
                copy.deepcopy(update_topo[min_row[0]][min_col[0]].update_delta_delete_topo_ed))
            # 本阶段删除的连接
            update_delta_topo_add = copy.deepcopy(update_topo[min_row[0]][min_col[0]].update_delta_add_topo)
            update_delta_topo_del_ed = update_delta_topo_del_ed.astype(int)
            update_delta_topo_delete -= update_delta_topo_del_ed
            # 更新待删除连接
            update_delta_topo_delete_tk[min_row[0]][min_col[0]] = copy.deepcopy(update_delta_topo_del_ed)
            deleted_links_all[min_row[0]][min_col[0]] += update_delta_topo_delete_tk[min_row[0]][min_col[0]]
            # 更新已删除连接

    return update_logical_topo, update_check_flag
