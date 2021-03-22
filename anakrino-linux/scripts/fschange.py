#!/bin/env python3
# 20210322 Kirby

from pprint import pprint
import sys
import gzip
import dumper
import pickle
import csv
import io
import re
import hashlib
import smtplib
import codecs
import getopt
import os
from email.mime.text import MIMEText

csv.register_dialect(
    'mydialect',
    delimiter=',',
    quotechar='"',
    escapechar='\\',
    doublequote=True,
    skipinitialspace=True,
    lineterminator='\r\n',
    quoting=csv.QUOTE_MINIMAL)

try:
    opts, args = getopt.getopt(sys.argv[1:], "", ["file=", "url=", "mailfrom=", "mailto=", "smtp="])
except getopt.GetoptError as err:
    print("Invalid args: %s", err)
    sys.exit(2)
mailFrom = 'anakrino@localhost'
mailTo = 'root@localhost'
smtp = 'localhost'
url = ''
for o, a in opts:
    if o in ("--file"):
        splunkReportFile = a
    elif o in ("--url"):
        splunkUrl = a
        splunkUrl = re.sub(r'/app/.*', "", a)
        splunkUrl += '/app/search/search?earliest=-7d%40h&lastest=now&q=search%20index%3Danakrino%20sourcetype%3Dfschange'
    elif o in ("--mailfrom"):
        mailFrom = a
    elif o in ("--mailto"):
        mailTo = a
    elif o in ("--smtp"):
        smtp = a
    else:
        assert False, "unhandled option"

if not os.path.isfile(splunkReportFile):
    print("File %s does not exist" % splunkReportFile)
    sys.exit(2)


fslog=list()
try:
    with gzip.open(splunkReportFile, 'rt') as f:
        #splunkReader = csv.reader(io.TextIOWrapper(f, newline=""), escapechar='\\', delimiter=',', quotechar='"')
        splunkReader = csv.DictReader(f, dialect='mydialect')
        for row in splunkReader:
            try:
                vals = [x.rsplit(', ', 1) for x in (row['_raw'].split('='))]
                fsdict = {}
                fsdict['hostname'] = row['host']
                while vals:
                    value = vals.pop()[0]
                    key = vals[-1].pop().split(' ').pop()
                    fsdict[key] = value
                    if len(vals[-1]) == 0:
                        break
                fslog.append(fsdict)
            except:
                pass
        f.close()
except ValueError as e:
    print("ValueError %s" % e)
except Exception as e:
    print("Exception %s" % e)
except:
    print("unable to open file %s" % splunkReportFile)


hashDict = {}
for row in fslog:
    try:
        plainText = str(row['path'] + row['action'] + row['chgs'] + row['mode'])
        myHash = hashlib.md5(plainText.encode('utf-8')).hexdigest()
        try:
            hashDict[myHash]['count'] += 1
        except:
            hashDict[myHash] = {}
            hashDict[myHash]['count'] = 1
            pass

        hashDict[myHash]['action'] = row['action']
        hashDict[myHash]['chgs'] = row['chgs']
        hashDict[myHash]['path'] = row['path']
        hashDict[myHash]['mode'] = row['mode']
        try:
            hashDict[myHash]['hostnames']
            if not row['hostname'] in hashDict[myHash]['hostnames']:
                hashDict[myHash]['hostnames'].append(row['hostname'])
        except:
            hashDict[myHash]['hostnames'] = list()
            hashDict[myHash]['hostnames'].append(row['hostname'])
            pass
    except:
        continue
# pprint(hashDict)
report = ''
# pprint(sortedDict)
# for myHash in hashDict:
for myRow in sorted(hashDict.items(), key = lambda x: x[1]['path']):
#    if hashDict[myHash]['chgs'] == '"modtime "':
    if myRow[1]['chgs'] == '"modtime "':
        continue
    # print("count: %s \n action: %s \n chgs: %s \n mode: %s \n path: %s" % (hashDict[myHash]['count'], hashDict[myHash]['action'], hashDict[myHash]['chgs'], hashDict[myHash]['mode'], hashDict[myHash]['path']))
    # print(" hosts: %s" % ' '.join(hashDict[myHash]['hostnames']))
    # print("#############################################")
    # print("CHG: %s %s MODE: %s PATH: %s\n\tHOSTS: %s\n" % (hashDict[myHash]['action'], hashDict[myHash]['chgs'], hashDict[myHash]['mode'], hashDict[myHash]['path'], ' '.join(hashDict[myHash]['hostnames'])))
#    report += 'CHG:' + hashDict[myHash]['action'] + ' ' + hashDict[myHash]['chgs'] + ' MODE:' + hashDict[myHash]['mode'] + ' PATH:' + hashDict[myHash]['path'] + "\n" + "HOSTS:" + ' '.join(hashDict[myHash]['hostnames']) + "\n\n"
    report += 'CHG:' + myRow[1]['action'] + ' ' + myRow[1]['chgs'] + ' MODE:' + myRow[1]['mode'] + ' PATH:' + myRow[1]['path'] + "\n" + "HOSTS:" + ' '.join(myRow[1]['hostnames']) + "\n\n"

print(report)
if report == '':
    print("Nothing to report")
    exit()
    

msg = MIMEText(report)
msg['Subject'] = 'fschange report'
msg['From'] = mailFrom
msg['To'] = mailTo

# Send the message via our own SMTP server.
s = smtplib.SMTP(smtp)
s.send_message(msg)
s.quit()
#
#
#
