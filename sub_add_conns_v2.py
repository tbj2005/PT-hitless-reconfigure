# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06月26日
"""
import copy
import time

import select_links
import numpy as np
import del_conns
import max_flow


def sub_add_conns_v2(inputs, update_logical_topo_weight, update_logical_topo, update_delta_topo_del,
                     links_tobe_add_topo, used_ind, del_update_logical_topo_all, index):
    """
    打断重连子函数
    :param index:
    :param inputs:
    :param update_logical_topo_weight:
    :param update_logical_topo:
    :param update_delta_topo_del:
    :param links_tobe_add_topo:
    :param used_ind:
    :param del_update_logical_topo_all:
    :return:
    """
    # mf = np.zeros([inputs.group_num, inputs.oxc_num_a_group])
    # add_connections = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
    # del_links_real = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
    # add_del_num = np.zeros([inputs.group_num, inputs.oxc_num_a_group])
    add_del_traffic = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
    # benefit = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
    # benefit = np.zeros([inputs.group_num, inputs.oxc_num_a_group])
    start = time.time()
    # can_rest_port = np.zeros([inputs.group_num, inputs.oxc_num_a_group])
    """
    for t in range(0, inputs.group_num):
        for k in range(0, inputs.oxc_num_a_group):
            update_logical_topo_kt = copy.deepcopy(update_logical_topo[t][k])
            rest_del_update_logical_topo = copy.deepcopy(update_logical_topo_kt)
            max_match_num = np.zeros(len(rest_del_update_logical_topo))
            free_ports_before_del = np.zeros(len(rest_del_update_logical_topo))
            for i_ind in range(0, len(rest_del_update_logical_topo)):
                max_match_num[i_ind] = inputs.physical_conn_oxc - np.sum(rest_del_update_logical_topo[i_ind, :])
                # 计算每个 node 的最大匹配数目
                free_ports_before_del[i_ind] = inputs.physical_conn_oxc - np.sum(update_logical_topo_kt[i_ind, :])
                # 计算每个 node 删除链接前可用的端口数目

            already_matched_nodes = []
            match_node = []
            for node_ind in range(0, inputs.nodes_num):
                already_matched_nodes = [node_ind] + already_matched_nodes
                match_cols = np.where(links_tobe_add_topo[node_ind])
                match_cols = match_cols[0]
                # 找到与各 node 相关的删除后待增加的连接
                match_cols = [x for x in match_cols if x not in already_matched_nodes]
                # 删掉之前的循环已经考虑过的连接
                match_cols = sorted(match_cols)
                match_node.append([[match_cols[i], links_tobe_add_topo[node_ind][match_cols[i]]] for i in
                                   range(0, len(match_cols))])
                # 将每个 node 相关未考虑删除后待增加连接和删除连接数目储存起来，每个 node 有一个数组，数组中每个元素都是二维数组，
                # 第一个元素存放未考虑删除后待增加连接的另一个 node ,第二个元素存放这两个 node 间删除后待增加连接的数目

            for i in range(0, inputs.nodes_num):
                for j in range(i, inputs.nodes_num):
                    rest_port = min(links_tobe_add_topo[i][j], max_match_num[i], max_match_num[j])
                    can_rest_port[t][k] += rest_port
    """
    ind = index - 1
    # 找到可用端口数目最多的子拓扑，为这个子拓扑计算执行最大流算法
    ind_row = int(ind / inputs.oxc_num_a_group)
    ind_col = int(ind % inputs.oxc_num_a_group)
    t = ind_row
    k = ind_col
    """
    for t in range(0, inputs.group_num):
        for k in range(0, inputs.oxc_num_a_group):
    """
    logical_topo_weight = np.zeros([inputs.nodes_num, inputs.nodes_num])
    for i in range(0, inputs.nodes_num):
        for j in range(i, inputs.nodes_num):
            # if len(update_logical_topo_weight[t][k][i][j]) == 0:
            if len(update_logical_topo_weight[t][k][i][j]) == 0:
                # 若更新后 weight 长度为 0 ，也就是说根本没有连接，将 node 对间的权重设为 0
                logical_topo_weight[i][j] = 0
            else:
                # 若更新后 weight 长度不为 0，令 node 对间的连接为最小权重连接，即第一条连接权重
                logical_topo_weight[i][j] = update_logical_topo_weight[t][k][i][j][0] + 0

    logical_topo_weight += logical_topo_weight.T
    """
    update_logical_topo_kt = copy.deepcopy(update_logical_topo[t][k])
    rest_del_update_logical_topo = copy.deepcopy(update_logical_topo_kt)
    max_match_num = np.zeros(len(rest_del_update_logical_topo))
    free_ports_before_del = np.zeros(len(rest_del_update_logical_topo))
    for i_ind in range(0, len(rest_del_update_logical_topo)):
        max_match_num[i_ind] = inputs.physical_conn_oxc - np.sum(rest_del_update_logical_topo[i_ind, :])
        # 计算每个 node 的最大匹配数目
        free_ports_before_del[i_ind] = inputs.physical_conn_oxc - np.sum(update_logical_topo_kt[i_ind, :])
        # 计算每个 node 删除链接前可用的端口数目
    """
    update_logical_topo_kt = copy.deepcopy(update_logical_topo[t][k])
    rest_del_update_logical_topo = copy.deepcopy(update_logical_topo_kt)
    max_match_num = np.zeros(len(rest_del_update_logical_topo))
    free_ports_before_del = np.zeros(len(rest_del_update_logical_topo))
    for i_ind in range(0, len(rest_del_update_logical_topo)):
        max_match_num[i_ind] = inputs.physical_conn_oxc - np.sum(rest_del_update_logical_topo[i_ind, :])
        # 计算每个 node 的最大匹配数目
        free_ports_before_del[i_ind] = inputs.physical_conn_oxc - np.sum(update_logical_topo_kt[i_ind, :])
        # 计算每个 node 删除链接前可用的端口数目

    already_matched_nodes = []
    match_node = []
    for node_ind in range(0, inputs.nodes_num):
        already_matched_nodes = [node_ind] + already_matched_nodes
        match_cols = np.where(links_tobe_add_topo[node_ind])
        match_cols = match_cols[0]
        # 找到与各 node 相关的删除后待增加的连接
        match_cols = [x for x in match_cols if x not in already_matched_nodes]
        # 删掉之前的循环已经考虑过的连接
        match_cols = sorted(match_cols)
        match_node.append([[match_cols[i], links_tobe_add_topo[node_ind][match_cols[i]]] for i in
                           range(0, len(match_cols))])
        # 将每个 node 相关未考虑删除后待增加连接和删除连接数目储存起来，每个 node 有一个数组，数组中每个元素都是二维数组，
        # 第一个元素存放未考虑删除后待增加连接的另一个 node ,第二个元素存放这两个 node 间删除后待增加连接的数目
    mf, add_connections = max_flow.max_flow(inputs, match_node, max_match_num)
    if mf != 0:
        mf, add_connections = (
            select_links.select_links(inputs, add_connections, links_tobe_add_topo, max_match_num))
        # 选择连接，使得满足节点度要求

    del_update_logical_topo = copy.deepcopy(del_update_logical_topo_all[t][k])
    add_connections1_check = [add_connections[n][0:2] for n in range(0, len(add_connections))]
    add_connections2_check = [[add_connections[n][1], add_connections[n][0]] for n in
                              range(0, len(add_connections))]
    # 保存待增加两种方向的连接
    rows_del, col_del = np.where(del_update_logical_topo)
    # 找到子拓扑删除连接相关的 node 对
    add_connections1 = [x for x in add_connections1_check if x not in [[rows_del[i], col_del[i]] for i in
                                                                       range(0, len(rows_del))]]
    del_update_logical_topo1 = np.triu(del_update_logical_topo)
    for del_links_topo_ind in range(0, len(add_connections1_check)):
        if del_update_logical_topo1[add_connections1_check[del_links_topo_ind][0]][add_connections1_check[
            del_links_topo_ind][1]] > 0:
            del_update_logical_topo1[add_connections1_check[del_links_topo_ind][0]][
                add_connections1_check[del_links_topo_ind][1]] = 0
        if del_update_logical_topo1[add_connections2_check[del_links_topo_ind][0]][add_connections2_check[
            del_links_topo_ind][1]] > 0:
            del_update_logical_topo1[add_connections2_check[del_links_topo_ind][0]][
                add_connections2_check[del_links_topo_ind][1]] = 0

    del_links_topo_row, del_links_topo_col = np.where(del_update_logical_topo1)
    del_links_topo = \
        np.array([np.array([del_links_topo_row[x], del_links_topo_col[
            x]]) for x in range(0, len(del_links_topo_row))])

    free_ports_before_del1 = copy.deepcopy(free_ports_before_del)
    # 表示每个端口的空闲数量
    for add_conn_ind in range(0, len(add_connections1)):
        if free_ports_before_del1[add_connections1[add_conn_ind][0]] > 0:
            free_ports_before_del1[add_connections1[add_conn_ind][0]] -= 1
            add_connections1[add_conn_ind][0] = 0
        if free_ports_before_del1[add_connections1[add_conn_ind][1]] > 0:
            free_ports_before_del1[add_connections1[add_conn_ind][1]] -= 1
            add_connections1[add_conn_ind][1] = 0

    if sum([sum(x) for x in add_connections1]) > 0:
        del_port_row, del_port_col = np.where(add_connections1)
        # 全空会报错
    else:
        del_port_row = []
        del_port_col = []
    del_ports = [add_connections1[del_port_row[i]][del_port_col[i]] for i in range(0, len(del_port_row))]

    if len(del_ports) > 0:
        if_in = np.zeros(len(del_links_topo))
        for che_ind in range(0, len(del_links_topo)):
            lia = [1 if x in del_ports else 0 for x in del_links_topo[che_ind]]
            if_in[che_ind] = sum(lia)

        sert_ind = np.argsort(if_in)
        del_links_topo_sorted = np.array([del_links_topo[sert_ind[x]] for x in range(0, len(sert_ind))])

        del_links_topo1 = copy.deepcopy(del_links_topo_sorted)

        for del_ind in range(0, len(del_ports)):
            if len(del_links_topo_sorted) > 0:
                row_ports_del, col_ports_del = np.where(del_links_topo_sorted == del_ports[del_ind])
                if len(row_ports_del) > 0:
                    del_links_topo1[row_ports_del[0]][col_ports_del[0]] = 0

        if len(del_links_topo1) > 0:
            del_real_row, _ = np.where(del_links_topo1 == 0)
            del_real_row = sorted(list(set(del_real_row)))
            del_links_real = (
                np.array([del_links_topo[del_real_row[x]] for x in range(0, len(del_real_row))]))
            add_del_num = len(del_links_real)
        else:
            del_links_real = []
            add_del_num = 0

        if del_links_real is not None:
            for del_real_ind in range(0, len(del_links_real)):
                if update_delta_topo_del[del_links_real[del_real_ind][0]][del_links_real[t][k][del_real_ind][1]] > 0:
                    add_del_num -= 1

        add_del_traffic[t][k] = sum([logical_topo_weight[del_links_real[t][k][n][0]][del_links_real[t][k][n][1]]
                                     for n in range(0, len(del_links_real[t][k]))])

        if inputs.method == 1:
            benefit = mf - add_del_num
        else:
            benefit = mf - add_del_traffic
    else:
        benefit = mf
        del_links_real = []
    tobe_add_topo = copy.deepcopy(links_tobe_add_topo)
    sub_AddLinks_row, sub_AddLinks_col = np.where(tobe_add_topo)
    sub_AddLinks = [[sub_AddLinks_row[i], sub_AddLinks_col[i]] for i in range(0, len(sub_AddLinks_row))]
    end = time.time()
    print("sub time", end - start)
    sub_AddLinks_change = []
    for sub_AddLinks_ind in range(0, len(sub_AddLinks_row)):
        AddLinks_val = tobe_add_topo[sub_AddLinks_row[sub_AddLinks_ind]][sub_AddLinks_col[sub_AddLinks_ind]]
        for i in range(0, int(AddLinks_val)):
            sub_AddLinks_change.append(sub_AddLinks[sub_AddLinks_ind])
    """
    if len(used_ind) > 0:
        for i in range(0, len(used_ind)):
            used_ind_row = int(used_ind[i] / inputs.oxc_num_a_group)
            used_ind_col = int(used_ind[i] % inputs.oxc_num_a_group)
            benefit = -np.Inf
    """
    # mark_ind = np.argmax(benefit)
    mark_row = ind_row
    mark_col = ind_col

    used_ind.append(ind)
    rest_add_delta_topo = np.zeros([inputs.nodes_num, inputs.nodes_num])

    if len(sub_AddLinks_change) > 0:
        add_links_tk_topo = [add_connections[k][0:2] for k in
                             range(0, len(add_connections))]
        if len(add_links_tk_topo) > 0:
            del_links_tk_topo = del_conns.del_conns(inputs, add_links_tk_topo, update_logical_topo[mark_row][mark_col],
                                                    del_update_logical_topo_all[mark_row][mark_col])
            update_logical_topo[mark_row][mark_col] += (del_update_logical_topo_all[mark_row][mark_col] -
                                                        (del_links_tk_topo + del_links_tk_topo.T))

            del_row, del_col = np.where(del_links_tk_topo)
            for del_weight_i in range(0, len(del_row)):
                if len(update_logical_topo_weight[mark_row][mark_col][del_row[del_weight_i]][
                           del_col[del_weight_i]]) > 1:
                    update_logical_topo_weight[mark_row][mark_col][del_row[del_weight_i]][del_col[del_weight_i]] = \
                        update_logical_topo_weight[mark_row][mark_col][del_row[del_weight_i]][del_col[del_weight_i]][1:]
                else:
                    update_logical_topo_weight[mark_row][mark_col][del_row[del_weight_i]][del_col[del_weight_i]] = []
                update_logical_topo_weight[mark_row][mark_col][del_col[del_weight_i]][del_row[del_weight_i]] = \
                    copy.deepcopy(update_logical_topo_weight[mark_row][mark_col][
                                      del_row[del_weight_i]][del_col[del_weight_i]])
            for add_links_tk_topo_ind in range(0, len(add_links_tk_topo)):
                add_row = add_links_tk_topo[add_links_tk_topo_ind][0]
                add_col = add_links_tk_topo[add_links_tk_topo_ind][1]
                update_logical_topo[mark_row][mark_col][add_row][add_col] += 1
                update_logical_topo[mark_row][mark_col][add_col][add_row] = update_logical_topo[mark_row][mark_col][
                                                                                add_row][add_col] + 0
                update_logical_topo_weight[mark_row][mark_col][add_col][add_row] = (
                        [0] + update_logical_topo_weight[mark_row][mark_col][add_col][add_row])
                update_logical_topo_weight[mark_row][mark_col][add_row][add_col] = (
                        [0] + update_logical_topo_weight[mark_row][mark_col][add_row][add_col])

            update_delta_topo_del -= del_links_tk_topo + del_links_tk_topo.T
            update_delta_topo_del[update_delta_topo_del < 0] = 0

            add_links_tk_topo_bi = add_links_tk_topo + [[add_links_tk_topo[i][1], add_links_tk_topo[i][0]] for i in
                                                        range(0, len(add_links_tk_topo))]

            for i in range(0, len(add_links_tk_topo_bi)):
                ismember = [1 if x == add_links_tk_topo_bi[i] else 0 for x in sub_AddLinks_change]
                if 1 in ismember:
                    idx_list = ismember.index(1)
                    del sub_AddLinks_change[idx_list]

        for tobe_add_links_ind in range(0, len(sub_AddLinks_change)):
            rest_add_delta_topo[sub_AddLinks_change[tobe_add_links_ind][0]][sub_AddLinks_change[
                tobe_add_links_ind][1]] += 1

    return rest_add_delta_topo, update_logical_topo, update_delta_topo_del, used_ind
