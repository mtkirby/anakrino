#!/bin/env python3
# 20160904 Kirby

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
import os
from email.mime.text import MIMEText
import difflib


splunkReportFile = sys.argv[1]
splunkHome = sys.argv[2]

csv.register_dialect(
    'mydialect',
    delimiter = ',',
    quotechar = '"',
    escapechar = '\\',
    doublequote = True,
    skipinitialspace = True,
    lineterminator = '\r\n',
    quoting = csv.QUOTE_MINIMAL)


hashDict = {}
try:
    with gzip.open(splunkReportFile, 'rt') as reportFD:
        splunkReader = csv.DictReader(reportFD, dialect='mydialect')
        for row in splunkReader:
            try:
                dstFile = splunkHome + '/var/fim-linux-diff/' + row['host'] + row['source']
                dstFileDir = os.path.dirname(dstFile)
                os.makedirs(dstFileDir, mode=0o700, exist_ok=True)
                if os.path.isfile(dstFile):
                    with open(dstFile, 'r') as dstFileRFD:
                        oldDstContent = dstFileRFD.read()
                    dstFileRFD.close()
                    raw = row['_raw'] + '\n'
                    diff = difflib.ndiff(oldDstContent.splitlines(keepends=True), raw.splitlines(keepends=True))
                    diff = difflib.ndiff(oldDstContent.splitlines(keepends=True), raw.splitlines(keepends=True))
                    delta = ''.join(x[0:] for x in diff if x.startswith('+ ') or x.startswith('- '))
                    if len(delta) == 0:
                        continue
                else:
                    delta = raw
                with open(dstFile, 'w') as dstFileWFD:
                    dstFileWFD.write(raw)
                    dstFileWFD.close()
#                    print("WROTE FILE %s" % dstFile)

                plainText = str(row['source'] + delta)
                myHash = hashlib.md5(plainText.encode('utf-8')).hexdigest()
                try:
                    hashDict[myHash]['count'] += 1
                except:
                    hashDict[myHash] = {}
                    hashDict[myHash]['count'] = 1
                    pass
        
                hashDict[myHash]['file'] = row['source']
                hashDict[myHash]['delta'] = delta
                try:
                    hashDict[myHash]['hosts']
                    if not row['host'] in hashDict[myHash]['hosts']:
                        hashDict[myHash]['hosts'].append(row['host'])
                except:
                    hashDict[myHash]['hosts'] = list()
                    hashDict[myHash]['hosts'].append(row['host'])
                    pass
#                print("host=%s\tfile=%s\n%s\n\n" % (row['host'], row['source'], delta))
#                print("host=%s\nsource=%s\n_raw=%s\n\n" % (row['host'], row['source'], row['_raw']))
            except:
                pass
        reportFD.close()
        report = ''
        for myRow in sorted(hashDict.items(), key = lambda x: x[1]['file']):
#            print("myrow %s" % myRow[1]['delta'])
            report += 'FILE:' + myRow[1]['file'] + "\n" + "HOSTS:" + ' '.join(myRow[1]['hosts']) + "\n" + myRow[1]['delta'] + "\n\n"
#            report += 'FILE:' + myRow[1]['file'] + "\n" + "HOSTS:" + ' '.join(myRow[1]['hosts']) + "\n\n"

        print(report)
        if report == '':
            print("Nothing to report")
            exit()


except ValueError as e:
    print("ValueError %s" % e)
except Exception as e:
    print("Exception %s" % e)
except:
    print("unable to open file %s" % splunkReportFile)


#
#
#
