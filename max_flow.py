# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06约26日
"""
import maxflow
import numpy as np
import pandas as pd
import networkx as nx
import matplotlib.pyplot as plt


def max_flow(inputs, match_node, max_match_num):
    mf = 0
    add_connections = []
    s = inputs.nodes_num * 2 + 1
    t = inputs.nodes_num * 2 + 2
    G = maxflow.Graph[float](2 * inputs.nodes_num, 2 * inputs.nodes_num)
    nodes = G.add_nodes(2 * inputs.nodes_num)
    for i in range(0, inputs.nodes_num):
        G.add_tedge(nodes[i], max_match_num[i], 0)
        G.add_tedge(nodes[i + inputs.nodes_num], 0, max_match_num[i])
    for i in range(0, inputs.nodes_num):
        match_node_i = match_node[i]
        if len(match_node_i) > 0:
            for j in range(0, len(match_node_i)):
                G.add_edge(nodes[i], match_node_i[j][0] + inputs.nodes_num, match_node_i[j][1], 0)
                add_connections.append([i, match_node_i[j][0], match_node_i[j][1]])

    mf = G.maxflow()
    print(add_connections)
    DG = G.get_nx_graph()
    del_add = []
    for i in range(0, inputs.nodes_num):
        for j in range(0, inputs.nodes_num):
            X = DG.get_edge_data(nodes[i], nodes[j + inputs.nodes_num])
            if isinstance(X, dict):
                for k in range(0, len(add_connections)):
                    if add_connections[k][0] == i and add_connections[k][1] == j:
                        add_connections[k][2] -= X['weight']
                    if add_connections[k][2] == 0:
                        del_add.append(k)
    add_connections = [x for x in add_connections if x not in del_add]

    return mf, add_connections
