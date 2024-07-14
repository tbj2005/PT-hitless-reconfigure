# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06约26日
"""
import maxflow


def max_flow(inputs, match_node, max_match_num):
    add_connections = []
    G = maxflow.Graph[float](2 * inputs.nodes_num, 2 * inputs.nodes_num)
    # 构造一个最大流问题的图
    # 使用 GraphFloat 类，以适应流为小数的场景
    nodes = G.add_nodes(2 * inputs.nodes_num)
    # 为图增加 2 * node 数目个节点，分为两部分，分别代表出组和入组，长度都为 node 数目
    for i in range(0, inputs.nodes_num):
        G.add_tedge(nodes[i], max_match_num[i], 0)
        G.add_tedge(nodes[i + inputs.nodes_num], 0, max_match_num[i])
        # 将节点分成两组，并为这些节点与源和目的节点间增加有向边，前一半 node 和源连接，不与目的节点连接，后一半反之
    for i in range(0, inputs.nodes_num):
        match_node_i = match_node[i]
        if len(match_node_i) > 0:
            # 如果 node 存在相关删除连接后产生的待增加连接
            for j in range(0, len(match_node_i)):
                G.add_edge(nodes[i], match_node_i[j][0] + inputs.nodes_num, match_node_i[j][1], 0)
                add_connections.append([i, match_node_i[j][0], match_node_i[j][1]])
                # 为前半部分 node 和后半部分 node 间添加边
                # add_connections 存放删除后待增加的连接，三元组表示[源 node,目的 node,删除后待增加的连接数目]，当前初始化该数组

    mf = G.maxflow()
    # 执行最大流算法，以可传输流量最大的方式获得连接使用结果和最大传输流量
    DG = G.get_nx_graph()
    del_add = []
    for i in range(0, inputs.nodes_num):
        for j in range(0, inputs.nodes_num):
            X = DG.get_edge_data(nodes[i], nodes[j + inputs.nodes_num])
            # 读取出每一对 node 间的 weight
            if isinstance(X, dict):
                for k in range(0, len(add_connections)):
                    if add_connections[k][0] == i and add_connections[k][1] == j:
                        add_connections[k][2] -= X['weight']
                        # 更新 add_connections
                    if add_connections[k][2] == 0:
                        del_add.append(k)
    add_connections = [x for x in add_connections if x not in del_add]

    return mf, add_connections
