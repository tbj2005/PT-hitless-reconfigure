# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06月27日
"""
import numpy as np


def beyond_nodes(inputs, sort_idx, max_match_num, asy_mm_links):
    beyondNodes = []
    node_i_rows_asy = np.empty(inputs.nodes_num, dtype=object)
    beyond_node_degree = np.empty(inputs.nodes_num, dtype=object)
    for node_i in range(0, inputs.nodes_num):
        node_i_rows_asy_1 = np.where([asy_mm_links[k][0] for k in range(0, len(asy_mm_links))] == sort_idx[node_i])
        node_i_rows_asy_1 = node_i_rows_asy_1[0]
        node_i_rows_asy_2 = np.where([asy_mm_links[k][1] for k in range(0, len(asy_mm_links))] == sort_idx[node_i])
        node_i_rows_asy_2 = node_i_rows_asy_2[0]
        node_i_rows_asy[node_i] = np.concatenate((node_i_rows_asy_1, node_i_rows_asy_2))
        beyond_node_degree[node_i] = len(node_i_rows_asy[node_i]) - max_match_num[sort_idx[node_i]]

        if beyond_node_degree[node_i] > 0:
            beyondNodes.append(sort_idx[node_i])

    num_b = np.zeros(len(asy_mm_links))

    for i in range(0, len(asy_mm_links)):
        for k in range(0, len(asy_mm_links[i])):
            num_b += asy_mm_links[i][k] in beyondNodes

    sorted_Indices = np.argsort(- num_b)
    asy_mm_links = [asy_mm_links[sorted_Indices[i]] for i in range(0, len(sorted_Indices))]

    return beyond_node_degree, asy_mm_links
