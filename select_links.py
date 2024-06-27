# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06月27日
"""
import numpy as np
import Beyond_Nodes


def select_links(inputs, add_connections, links_tobe_add_topo, max_match_num):
    asy_mm_links = []
    for i in range(0, len(add_connections)):
        asy_mm_links.append([np.tile(add_connections[i, 0:2], add_connections[i, 2])])

    node_num = np.sum(links_tobe_add_topo, axis=1)

    sort_idx = np.argsort(node_num)

    beyond_nodes = []
    node_i_rows_asy = np.empty(inputs.nodes_num, dtype=object)
    beyond_node_degree = np.empty(inputs.nodes_num, dtype=object)
    for node_i in range(0, inputs.nodes_num):
        node_i_rows_asy_1, _ = np.where(asy_mm_links[:, 0] == sort_idx[node_i])
        node_i_rows_asy_2, _ = np.where(asy_mm_links[:, 2] == sort_idx[node_i])
        node_i_rows_asy[node_i] = [node_i_rows_asy_1, node_i_rows_asy_2]
        beyond_node_degree[node_i] = len(node_i_rows_asy) - max_match_num[sort_idx]

        if beyond_node_degree[node_i] > 0:
            beyond_nodes.append(sort_idx[node_i])

    num_b = np.zeros(len(asy_mm_links))

    for i in range(0, len(asy_mm_links)):
        for k in range(0, len(asy_mm_links[i])):
            num_b += asy_mm_links[i][k] in beyond_nodes

    sorted_Indices = np.argsort(num_b)[::-1]
    asy_mm_links = asy_mm_links[:, sorted_Indices]

    Index = np.argsort(beyond_node_degree)
    while beyond_node_degree[Index] > 0:
        if len(asy_mm_links) > 0:
            del_asy_num = np.zeros(len(Index))
            for i in range(0, len(Index)):
                del_asy_num[i] = len(node_i_rows_asy[Index[i]]) - max_match_num[sort_idx[Index[i]]]
                asy_mm_links[0:del_asy_num] = []

        beyond_node_degree, asy_mm_links = Beyond_Nodes.beyond_nodes(inputs, sort_idx, max_match_num, asy_mm_links)
        Index = np.argsort(beyond_node_degree)

    add_connections_real = asy_mm_links
    graph_weight = len(add_connections_real)
    return graph_weight, add_connections_real
