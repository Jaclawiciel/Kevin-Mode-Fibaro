import sys, getopt
import numpy as np
import pandas as pd
import requests
import json
from datetime import datetime
from pytz import timezone
from calendar import timegm
from pprint import pprint

# Script for fetching data from Fibaro API energy consumption panel and saving it to CSV file as light on/off events

HC2_IP = "192.168.1.15"
USERNAME = "admin"
PASSWORD = "admin"
DIMMER_TYPE = "com.fibaro.FGD212"
DATE_FORMAT_PRETTY = '%Y-%m-%d, %H:%M'


def get_script_arguments(argv):
	outputfile = ''
	light_ids = ''
	start_date_pretty = ''
	end_date_pretty = ''

	try:
		opts, args = getopt.getopt(argv, "hl:o:", ["help", "lightIds", "outputfile", "startdate=", "enddate="])
	except getopt.GetoptError:
		print("energyPanelToCsv.py -o <outputfile> -l <lightIds> --startdate <'YYYY-mm-dd, HH:MM'> --enddate <'YYYY-mm-dd, HH:MM'>")
		sys.exit(2)
	for opt, arg in opts:
		if opt in ('-h', "--help"):
			print("energyPanelToCsv.py -o <outputfile> -l <lightIds> --startdate <'YYYY-mm-dd, HH:MM'> --enddate <'YYYY-mm-dd, HH:MM'>")
			sys.exit()
		elif opt in ('-l', '--lightIds'):
			light_ids = arg
		elif opt in ("-o", "--outputfile"):
			outputfile = arg
		elif opt == "--startdate":
			start_date_pretty = arg
		elif opt == "--enddate":
			end_date_pretty = arg

	if outputfile == '':
		raise getopt.GetoptError("Output file name missing!")
	if start_date_pretty == '':
		start_date_pretty = '1970-01-02, 00:00'
	if end_date_pretty == '':
		end_date_pretty = datetime.now().strftime(DATE_FORMAT_PRETTY)

	try:
		start_date = datetime.strptime(start_date_pretty, DATE_FORMAT_PRETTY)
		start_date = timezone('Europe/Amsterdam').localize(start_date)
		end_date = datetime.strptime(end_date_pretty, DATE_FORMAT_PRETTY)
		end_date = timezone('Europe/Amsterdam').localize(end_date)
	except ValueError:
		print("Something went wrong with date parsing...")
		sys.exit(2)

	if start_date > end_date:
		raise ValueError(f"Start date ({start_date_pretty}) is after end date ({end_date_pretty})")
		sys.exit(2)

	return {
		"output_file_name": outputfile,
		"light_ids": light_ids,
		"start_date": start_date,
		"end_date": end_date
	}


def get_timestamp(date):
	return timegm(date.utctimetuple())


def get_pretty_date(date):
	return date.strftime("%Y-%m-%d, %H:%M")


def get_lights(light_ids=None):
	lights = []
	if light_ids is None or light_ids == ['']:
		print("Light IDs not specified. Getting all the lights from Fibaro API\n")
		devices = requests.get(f"http://{HC2_IP}/api/devices", auth=(USERNAME, PASSWORD))
		devices = pd.DataFrame(devices.json(), columns=['id', 'type', 'name', 'roomID', 'visible'])
		devices = devices.loc[devices['visible']]
		lights = devices.loc[devices['type'] == DIMMER_TYPE]
		lights = lights.drop(['type', 'visible'], axis='columns')
	else:
		print(f"Getting data from Fibaro API for lights with IDs: {', '.join(light_ids)}\n")
		for light_id in light_ids:
			light = requests.get(f"http://{HC2_IP}/api/devices/{light_id}", auth=(USERNAME, PASSWORD)).json()
			lights.append(light)

		lights = pd.DataFrame(lights, columns=['id', 'name', 'roomID'])

	lights.rename(index=str, columns={'id': 'lightID', 'name': 'lightName'}, inplace=True)
	return lights

def get_light_ids():
	devices = requests.get(f"http://{HC2_IP}/api/devices", auth=(USERNAME, PASSWORD))
	devices = pd.DataFrame(devices.json(), columns=['id', 'type', 'name', 'roomID', 'visible'])
	devices = devices.loc[devices['visible']]
	lights = devices.loc[devices['type'] == DIMMER_TYPE]
	lights = lights.drop(['type', 'visible'], axis='columns')
	lights['id'] = lights['id'].astype(str)
	return lights.id.values


def get_rooms(room_ids):
	rooms = []
	for room_id in room_ids:
		room = requests.get(f"http://{HC2_IP}/api/rooms/{room_id}", auth=(USERNAME, PASSWORD)).json()
		rooms.append(room)
	rooms = pd.DataFrame(rooms, columns=['id', 'name', 'sectionID'])
	rooms.rename(index=str, columns={'id': 'roomID', 'name': 'roomName'}, inplace=True)
	rooms.set_index('roomID', inplace=True)
	return rooms


def get_sections(section_ids):
	sections = []
	for section_id in section_ids:
		section = requests.get(f"http://{HC2_IP}/api/sections/{section_id}", auth=(USERNAME, PASSWORD)).json()
		sections.append(section)
	sections = pd.DataFrame(sections, columns=['id', 'name'])
	sections.rename(index=str, columns={"id": "sectionID", "name": "sectionName"}, inplace=True)
	sections.set_index('sectionID', inplace=True)
	return sections


def get_light_events(light_ids):
	if light_ids is None or light_ids == ['']:
		light_ids = get_light_ids()

	energy_consumptions = requests.get(f"http://{HC2_IP}/api/energy/{start_date_timestamp}/{end_date_timestamp}/comparison-graph/devices/power/{','.join(light_ids)}").json()
	energy_consumptions = pd.DataFrame(energy_consumptions, columns=['id', 'data'])
	energy_consumptions.rename(index=str, columns={'id': 'lightID'}, inplace=True)
	print(energy_consumptions)

	light_events = []
	for index, light_id in enumerate(light_ids):
		energy_consumption = pd.DataFrame(energy_consumptions[energy_consumptions['lightID'] == int(light_id)]['data'][0], columns=['timestamp', 'state'])
		energy_consumption['lightID'] = light_id
		energy_consumption.loc[energy_consumption.state > 0, 'state'] = "on"
		energy_consumption.loc[energy_consumption.state == 0, 'state'] = "off"

		light_events.append(energy_consumption)
	light_events = pd.concat(light_events)
	light_events = light_events.drop(light_events.index[0])
	return light_events


def save_json(file_name, data):
	try:
		json_file = open(file_name, "w")
		json_file.write(data)
	except FileNotFoundError as e:
		print(f"Could not open the file \'{arguments['input_file_name']}\'\n{e}")
		sys.exit(2)
	finally:
		json_file.close()


def save_to_file(file_name, data):
	try:
		file = open(file_name, "w")
		file.write(data)
	except FileNotFoundError as e:
		print(f"Could not open the file \'{arguments['input_file_name']}\'\n{e}")
		sys.exit(2)
	finally:
		file.close()


arguments = get_script_arguments(sys.argv[1:])

output_file = arguments["output_file_name"]
start_date = arguments["start_date"]
end_date = arguments["end_date"]
light_ids = arguments["light_ids"].split(',')
start_date_timestamp = get_timestamp(start_date)
end_date_timestamp = get_timestamp(end_date)

print("Preparing lights usage data from Fibaro")
print(f"Start date: {get_pretty_date(arguments['start_date'])}\nEnd date: {get_pretty_date(arguments['end_date'])}")
print(20 * "-" + "\n")

print("Loading lights...")
lights = get_lights(light_ids)
print("Lights loaded\n")
print("Loading rooms...")
room_ids = lights['roomID'].unique()
rooms = get_rooms(room_ids)
print("Rooms loaded\n")
print("Loading sections...")
section_ids = rooms['sectionID'].unique()
sections = get_sections(section_ids)
print("Sections loaded\n")
data = lights.join(rooms, on='roomID').join(sections, on='sectionID')
print("Loading light events...")
light_events = get_light_events(light_ids)
data = lights.join(rooms, on='roomID').join(sections, on='sectionID')
data['lightID'] = data['lightID'].astype(int)
light_events['lightID'] = light_events['lightID'].astype(int)
print("Light events loaded\n")
print("Combining the data...")
data = pd.merge(light_events, data, on='lightID', how='outer')
data.sort_values(['timestamp', 'sectionID', "roomID", 'lightID'], inplace=True)
data['timestamp'] = data['timestamp'].astype(str)
data['timestamp'] = data.timestamp.apply(lambda x: x[:-3])
data.index.name = 'id'
print("Data combined\n")
print(f"Saving data to '{output_file}'")
save_to_file(output_file, data.to_csv())
print("File saved\n")

print("Data sample")
print(90 * "-" + "")
print(data.head())
print(90 * "-" + "\n")