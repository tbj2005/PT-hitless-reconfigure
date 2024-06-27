# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06约27日
"""
import copy

import numpy as np


def del_conns(inputs, add_links_tk_topo, update_logical_topo, del_update_logical_topo):
    del_links_topo = np.triu(del_update_logical_topo)
    del_ports = copy.deepcopy(add_links_tk_topo)

    origin_update_logical_topo = update_logical_topo + del_update_logical_topo
    free_ports_num = np.empty(inputs.nodes_num, dtype=int)
    for i_ind in range(0, inputs.nodes_num):
        index = np.where(del_ports == i_ind)
        if len(index) > 0:
            free_ports_num[i_ind] = inputs.physical_conn_oxc - sum(origin_update_logical_topo[i_ind])
            min_ind = min(len(index), free_ports_num[i_ind])
            del_ports = [x for i, x in enumerate(del_ports) if i not in index[0:min_ind]]

    del_links_real = []

    if del_ports:
        if_in = np.zeros(len(del_links_topo))
        for che_ind in range(0, len(del_links_topo)):
            lia = [x for x in del_links_topo[che_ind] if x in del_ports]
            if_in[che_ind] = sum(lia)

        sort_ind = np.argsort(if_in)
        del_links_topo_sorted = [del_links_topo[sort_ind[i]] for i in range(0, len(sort_ind))]

        del_links_topo1 = copy.deepcopy(del_links_topo_sorted)

        for del_ind in range(0, len(del_ports)):
            row_ports_del, col_ports_del = np.where(del_links_topo_sorted == del_ports[del_ind])
            if row_ports_del:
                del_links_topo1[row_ports_del[0]][col_ports_del[0]] = 0
        del_real_row, _ = np.where(del_links_topo1 == 0)
        del_real_row = sorted(list(set(del_real_row)))
        del_links_real = [del_links_topo[del_real_row[i]] for i in range(0, len(del_real_row))]

    return del_links_real
