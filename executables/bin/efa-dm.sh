#!/bin/sh
# efa.sh - Departure Monitor for public transportiation using EFA
#
# Copyright (c) 2018 Jan Holthuis
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

for dep in 'curl' 'awk' 'jq'; do
    ( ! command -v "$dep" >/dev/null 2>&1 ) && printf 'Error: %s not installed.\n' "$dep" >&2 && exit 2
done

API_ENDPOINT="http://www2.vvs.de/vvs/XSLT_DM_REQUEST"
PRETTY=0
DEBUG=0
TIME_OFFSET=0
NUM_DEPARTS=8
STOP_NAME="Stadtmitte"

usage() { cat <<EOF >&2
Usage: $0 [-p] [-d] [-a <API_ENDPOINT>] [-n <NUM_DEPARTS>] [-t <TIME_OFFSET>] <STOP_NAME>

Options:
  -h                 Show this help
  -p                 Pretty-printed output (instead of tab-separated values)
  -d                 Debug mode (output server reply and exit)
  -a <API_ENDPOINT>  Use API endpoint at this URL
  -n <NUM_DEPARTS>   Limit the number of departures (default: $NUM_DEPARTS)
  -t <TIME_OFFSET>   Skip departures in next X minutes (default: $TIME_OFFSET)
EOF
    exit 1
}

while getopts ":hdpa:n:t:" opt; do
    case "$opt" in
        h)
            usage
            exit 1
            ;;
        d)
            DEBUG=1
            ;;
        p)
            PRETTY=1
            ;;
        a)
            API_ENDPOINT="$OPTARG"
            ;;
        n)
            NUM_DEPARTS="$OPTARG"
            ;;
        t)
            TIME_OFFSET="$OPTARG"
            ;;
        \?)
            echo "ERROR: Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "ERROR: Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
        *)
            usage
            exit 1
    esac
done
shift "$((OPTIND-1))"

STOP_NAME="$1"
[ -z "$STOP_NAME" ] && usage


DMOUTPUT=$(curl -s --data-urlencode "name_dm=${STOP_NAME}" --data-urlencode "limit=${NUM_DEPARTS}" --data-urlencode "timeOffset=${TIME_OFFSET}" --data "language=de&type_dm=stop&mode=direct&dmLineSelectionAll=1&depType=STOPEVENTS&includeCompleteStopSeq=0&useRealtime=1&outputFormat=json" "${API_ENDPOINT}")
[ "$DEBUG" -ne 0 ] && printf "%s" "$DMOUTPUT" && exit 0

DMERROR="$(printf "%s" "$DMOUTPUT" | jq  -r 'if .["departureList"] == null then .["dm"]["message"?][] | select (.name == "code")["value"] else 0 end')"
case "$DMERROR" in
    0)
        # Looks like everything worked fine
        ;;
    "")
        printf 'ERROR: Invalid JSON returned by API endpoint.' >&2
        ;;
    *)
        printf 'ERROR: Code '%s' returned.\n' "$DMERROR" >&2
        DMSTOPSUGGESTIONS="$(printf "%s" "$DMOUTPUT" | jq -r '.["dm"]["points"?][] | "- \(.["name"]) [\(.["ref"]["id"])]"')"
        [ ! -z "$DMSTOPSUGGESTIONS" ] && printf 'You probably used an invalid or ambigous stop name, did you mean one of these?\n%s\n' "$DMSTOPSUGGESTIONS" >&2
        exit 3
esac

DMTABLE=$(printf "%s" "$DMOUTPUT" | jq -r '.["departureList"][] | [.["countdown"], .["dateTime"]["year"], .["dateTime"]["month"], .["dateTime"]["day"], .["dateTime"]["hour"], .["dateTime"]["minute"], .["realDateTime"]["year"], .["realDateTime"]["month"], .["realDateTime"]["day"], .["realDateTime"]["hour"], .["realDateTime"]["minute"], .["servingLine"]["number"], .["servingLine"]["direction"]] | @tsv')

if [ "$PRETTY" -ne 0 ]; then
    printf '%s' "$DMTABLE" | gawk -F'\t' -v timeoffset="${TIME_OFFSET}" '$7==""{ printf("%02d:%02d %s %s in %d min\n", $5, $6, $12, $13, $1+timeoffset) }; $7!=""{ x=(mktime($7" "$8" "$9" "$10" "$11" 00")-mktime($2" "$3" "$4" "$5" "$6" 00"))/60; if(x == 0) printf("%02d:%02d %s %s in %d min\n", $5, $6, $12, $13, $1+timeoffset); else printf("%02d:%02d(+%d) %s %s in %d min\n", $5, $6, x, $12, $13, $1+timeoffset) }'
else
    printf '%s\n' "$DMTABLE"
fi
