import numpy as np
import copy


def target_topo_convert(S_Conn_cap, S, logical_topo, update_logical_topo, port_allocation_inti_topo, inputs):
    S_Conn_cap_1 = copy.deepcopy(S_Conn_cap)
    E1 = copy.deepcopy(S)
    T = inputs.group_num
    K = inputs.oxc_num_a_group
    method = inputs.method
    sum_row = np.zeros([T, K, inputs.nodes_num])
    sum_col = np.zeros([T, K, inputs.nodes_num])
    del_logical_topo = np.empty((T, K), dtype=object)
    add_logical_topo = np.empty((T, K), dtype=object)
    for t in range(0, T):
        for k in range(0, K):
            """
            for de in range(0, inputs.nodes_num):
                sum_row[t][k][de] = np.sum(update_logical_topo[t][k], axis=1)[de]
                sum_col[t][k][de] = np.sum(update_logical_topo[t][k], axis=0)[de]
            """
            del_logical_topo[t][k] = logical_topo[t][k] - update_logical_topo[t][k]
            del_logical_topo[t][k][del_logical_topo[t][k] < 0] = 0
            add_logical_topo[t][k] = update_logical_topo[t][k] - logical_topo[t][k]
            add_logical_topo[t][k][add_logical_topo[t][k] < 0] = 0

            conn_row, conn_col = np.where(np.triu(del_logical_topo[t][k]))
            for conn_ind in range(0, len(conn_row)):
                zero_rows = [1 if S_Conn_cap_1[k][4] == -1 and S_Conn_cap_1[k][5] == -1 else 0 for k in
                             range(0, len(S_Conn_cap_1))]
                S_Conn_cap_1 = [x for i, x in enumerate(S_Conn_cap_1) if zero_rows[i] != 1]

                lia = [1 if [S_Conn_cap_1[k][0], S_Conn_cap_1[k][1]] == [conn_row[conn_ind], conn_col[conn_ind]] else 0
                       for k in range(0, len(S_Conn_cap_1))]
                conn_row_ind = np.where(lia)
                conn_row_ind = conn_row_ind[0]
                pods_port_cap = np.array([S_Conn_cap_1[conn_row_ind[i]][6] for i in range(0, len(conn_row_ind))])

                if method == 2 or method == 3:
                    sorted_port_cap_ind = np.argsort(-1 * pods_port_cap)
                else:
                    sorted_port_cap_ind = np.argsort(pods_port_cap)

                sorted_ports = [S_Conn_cap_1[conn_row_ind[sorted_port_cap_ind[k]]] + [] for k in
                                range(0, len(sorted_port_cap_ind))]
                lia_group = [1 if sorted_ports[n][2] == t and sorted_ports[n][3] == k else 0 for n in
                             range(0, len(sorted_ports))]
                group_row = np.where(lia_group)[0]
                sorted_ports1 = [sorted_ports[group_row[n]] for n in range(0, len(group_row))]

                used_ports_num = int(del_logical_topo[t][k][conn_row[conn_ind]][conn_col[conn_ind]])
                used_index = np.where(lia_group)[0]
                if used_ports_num < len(used_index):
                    used_index = used_index[:used_ports_num]
                S_conn_cap_sort_ind = [conn_row_ind[sorted_port_cap_ind[n]] for n in range(0, len(sorted_port_cap_ind))]
                used_ports_loc = [S_conn_cap_sort_ind[used_index[n]] for n in range(0, len(used_index))]
                for i in range(0, len(used_ports_loc)):
                    S_Conn_cap_1[used_ports_loc[i]][4] = -1
                    S_Conn_cap_1[used_ports_loc[i]][5] = -1
                    S_Conn_cap_1[used_ports_loc[i]][6] = 0

                for ii in range(0, int(del_logical_topo[t][k][conn_row[conn_ind]][conn_col[conn_ind]])):
                    E1[sorted_ports1[ii][4]][sorted_ports1[ii][5]][k][t] = 0
                    E1[sorted_ports1[ii][5]][sorted_ports1[ii][4]][k][t] = 0

                    port_allocation_inti_topo[t][k][0][sorted_ports1[ii][4]] = conn_row[conn_ind]
                    port_allocation_inti_topo[t][k][0][sorted_ports1[ii][5]] = conn_col[conn_ind]

            conn_row, conn_col = np.where(np.triu(add_logical_topo[t][k]))
            for conn_ind in range(0, len(conn_row)):
                pod_u_col = np.where(port_allocation_inti_topo[t][k][0] == conn_row[conn_ind])
                pod_u_col = pod_u_col[0]
                pod_v_col = np.where(port_allocation_inti_topo[t][k][0] == conn_col[conn_ind])
                pod_v_col = pod_v_col[0]

                for ii in range(0, int(add_logical_topo[t][k][conn_row[conn_ind]][conn_col[conn_ind]])):
                    E1[pod_u_col[ii]][pod_v_col[ii]][k][t] = 1
                    E1[pod_v_col[ii]][pod_u_col[ii]][k][t] = 1

                    port_allocation_inti_topo[t][k][0][pod_u_col[ii]] = -1
                    port_allocation_inti_topo[t][k][0][pod_v_col[ii]] = -1

    return E1
