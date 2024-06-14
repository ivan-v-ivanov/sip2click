import sys
import re
from collections import Counter


def group_connections(data, server_name) -> list:
    """
    Find calls info according to hostname
    :param data: raw tcpdump data
    :param server_name: hostname
    :return: list of calls info
    """
    connections = [[]]
    for line in data:
        if f' > {server_name}' in line:
            connections.append([])
        connections[-1].append(line)
    connections = connections[1:]
    return connections


def get_connection_info(connection, sip_pattern=r'(SIP\/2\.0) [2,3,4]..'):
    """
    Parse data from group_connections() and get: time; server; response_codes for all calls
    :param connection: one connection that possibly contain call info (list element)
    :param sip_pattern: pattern to find call info in tcpdump data
    :return: time of call; hostname; response codes
    """
    connection_header = connection[0].split()
    time = f"{connection_header[0]} {connection_header[1]}"
    server = connection_header[5].split('.')[0]
    try:
        status = \
            re.search(sip_pattern, [el for el in connection if re.search(sip_pattern, el)][0]).group().split()[1]
    except IndexError:
        status = None
    return time, server, status


def read_dumpfile(datafile=None,
                  server_name=None) -> dict:
    """
    Summarizer of parsing methods.
    Reads tcpdump and returns dictionary with all found calls
    :param datafile: raw tcpdump file
    :param server_name: hostname
    :return: dictionary with datetime; status; server for each call
    """
    with open(datafile, 'r') as data:
        data = data.readlines()
    connections = group_connections(data, server_name)

    calls_data_dict = {'datetime': [],
                       'status': [],
                       'server': []}

    for i, connection_data in enumerate(connections, 1):
        time, server, status = get_connection_info(connection_data)

        calls_data_dict['datetime'].append(time.split('.')[0])
        calls_data_dict['status'].append(status)
        calls_data_dict['server'].append(server)
    return calls_data_dict


def calls_data_output(calls_data_from_dumpfile, timedelta=None):
    """
    Creates proper output of calls information for created Clickhouse DB.
        STDOUT string: TIME?HOSTNAME?CODE_1:n1;CODE_2:n2;..CODE_N:nN
        STDERR string: No data
    :param calls_data_from_dumpfile:  dictionary of parsed tcpdump data
    :param timedelta: value of calls collection time to calculate calls per minute
    """
    try:
        server_datetime = calls_data_from_dumpfile['datetime'][-1]
        server_inputs = dict(Counter(calls_data_from_dumpfile['server']))
        response_codes = dict(Counter(calls_data_from_dumpfile['status']))

        print(server_datetime, end='?')
        print(list(server_inputs.keys())[0], end='?')

        for i, key in enumerate(response_codes.keys(), 1):
            string_end = ';' if i < len(response_codes.keys()) else ''
            print(f"{key}: {round(response_codes[key] / int(timedelta) * 60, 2)}", end=string_end)

    except IndexError:
        print('No data', file=sys.stderr)


"""
INPUT PARAMETERS:
    1. path to tcpdump.data file
    2. hostname (defined by uname command)
    3. timestep for datastore (in sec)
"""

if __name__ == '__main__':
    calls_data = read_dumpfile(datafile=sys.argv[1],
                               server_name=sys.argv[2])
    calls_data_output(calls_data, timedelta=sys.argv[3])
