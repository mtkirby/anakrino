#!/bin/env python3
# 20161203 Kirby

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
        splunkUrl += '/app/search/search?earliest=-7d%40h&lastest=now&q=search%20index%3Dsigcheck'
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
                <th>Path</th>
                <th>Verified</th>
                <th>Date</th>
                <th>Publisher</th>
                <th>Description</th>
                <th>Product</th>
                <th>SHA1</th>
            </tr>
"""

try:
    with gzip.open(splunkReportFile, 'rt') as f:
        splunkReader = csv.DictReader(f, dialect='mydialect')
        for row in splunkReader:
            try:
                report += '<tr>'
                report += '<tr><td><a href="' + splunkUrl + '%20host%3D' + row['host'] + '">' + row['host'] + '</a></td>'
                report += '<td>' + row['Path'] + '</td>'
                report += '<td>' + row['Verified'] + '</td>'
                report += '<td>' + row['Date'] + '</td>'
                report += '<td>' + row['Publisher'] + '</td>'
                report += '<td>' + row['Description'] + '</td>'
                report += '<td>' + row['Product'] + '</td>'
                report += '<td>' + row['SHA1'] + '</td>'
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
msg['Subject'] = 'sigcheck report'
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
