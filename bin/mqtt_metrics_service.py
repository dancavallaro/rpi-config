#!/usr/bin/env python

import paho.mqtt.client as mqtt

import boto3
from botocore.config import Config
import re


HEARTBEAT_TOPIC_REGEX = re.compile("device/(.+)/heartbeat")

HEARTBEAT_METRIC_NAMESPACE = "Testing123" # TODO: "RPiMonitoring"
HEARTBEAT_METRIC_NAME = "DeviceHeartbeat"
HEARTBEAT_METRIC_DIMENSION = "Device"

AWS_CONFIG = Config(region_name="us-east-1")
Cloudwatch = boto3.client("cloudwatch", config=AWS_CONFIG)


def on_connect(client, userdata, flags, rc):
  client.subscribe("device/+/heartbeat")

def parse_device(message):
  return HEARTBEAT_TOPIC_REGEX.match(message.topic).group(1)

def publish_heartbeat(device):
  Cloudwatch.put_metric_data(
    Namespace=HEARTBEAT_METRIC_NAMESPACE,
    MetricData=[
      {
        "MetricName": HEARTBEAT_METRIC_NAME,
        "Dimensions": [
          {
            "Name": HEARTBEAT_METRIC_DIMENSION,
            "Value": device
          }
        ],
        "Value": 1
      }
    ]
  )

def on_message(client, userdata, message):
  device = parse_device(message)
  msg = message.payload.decode("utf-8")

  if msg == "OK":
    print(f"Received heartbeat for device '{device}'")
    publish_heartbeat(device)
    print("Published heartbeat metric to CloudWatch")
  else:
    print(f"Received invalid heartbeat message for device '{device}': '{msg}'")


client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message
# TODO: Don't put this in source control
client.username_pw_set("rpi", "DHV6x48uBtYI83Ppu0tEWBmH")
client.connect("localhost")

client.loop_forever()
