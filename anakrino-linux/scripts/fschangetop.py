#!/bin/env python3
# 20160918 Kirby

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
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart


csv.register_dialect(
    'mydialect',
    delimiter=',',
    quotechar='"',
    escapechar='\\',
    doublequote=True,
    skipinitialspace=True,
    lineterminator='\r\n',
    quoting=csv.QUOTE_MINIMAL)


splunkReportFile=sys.argv[1]
splunkUrl = re.sub(r'/app/.*', "", sys.argv[2])
splunkUrl += '/app/search/search?earliest=-7d%40h&lastest=now&q=search%20index%3Dfschange%20sourcetype%3Dfschange'

report = """
    <!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
        <html>
            <meta content="text/html;charset=ISO-8859-1" http-equiv="Content-Type">
            <body link="black">
"""
report += '<a href="' + splunkUrl + '">Click here to view past 7 days in Splunk</a>'
report += """
            <br><br>
            <table cellspacing=1 border=1 width="100%" rules=all>
            <tr>
                <th>host</th>
                <th>action</th>
                <th>count</th>
            </tr>
"""

try:
    with gzip.open(splunkReportFile, 'rt') as f:
        splunkReader = csv.DictReader(f, dialect='mydialect')
        for row in splunkReader:
            try:
                report += '<tr>'
                report += '<td><a href="' + splunkUrl + '%20host%3D' + row['host'] + '">' + row['host'] + '</a></td>'
                report += '<td>' + row['action'] + '</td>'
                report += '<td>' + row['count'] + '</td>'
                report += '</tr>' + "\n"
            except:
                pass
        f.close()
except ValueError as e:
    print("ValueError %s" % e)
    exit()
except Exception as e:
    print("Exception %s" % e)
    exit()
except:
    print("unable to open file %s" % splunkReportFile)
    exit()

report += "\n</table></body></html>\n"

print(report)
if report == '':
    print("Nothing to report")
    exit()
    

htmlreport = MIMEText(report, 'html')
msg = MIMEMultipart('alternative')
msg['Subject'] = 'fschangetop report'
msg['From'] = 'fschange@localhost'
msg['To'] = 'root'
msg.attach(htmlreport)

# Send the message via our own SMTP server.
s = smtplib.SMTP('localhost')
s.send_message(msg)
s.quit()
#
#
#
