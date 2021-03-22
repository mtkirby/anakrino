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
        splunkUrl += '/app/search/search?earliest=-7d%40h&lastest=now&q=search%20index%3Danakrino%20sourcetype%3Dpkgcheck'
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
                <th>pkg</th>
                <th>file</th>
                <th>comments</th>
            </tr>
"""

try:
    with gzip.open(splunkReportFile, 'rt') as f:
        splunkReader = csv.DictReader(f, dialect='mydialect')
        for row in splunkReader:
            try:
                report += '<tr>'
                report += '<td><a href="' + splunkUrl + '%20host%3D' + row['host'] + '">' + row['host'] + '</a></td>'
                report += '<td>' + row['pkg'] + '</td>'
                report += '<td>' + row['file'] + '</td>'
                report += '<td>' + row['comments'] + '</td>'
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

report += '</table></body></html>'

print(report)
if report == '':
    print("Nothing to report")
    exit()


htmlreport = MIMEText(report, 'html')
msg = MIMEMultipart('alternative')
msg['Subject'] = 'pkgcheck report'
msg['From'] = mailFrom
msg['To'] = mailTo
msg.attach(htmlreport)

# Send the message via our own SMTP server.
s = smtplib.SMTP(smtp)
s.send_message(msg)
s.quit()
#
#
#
