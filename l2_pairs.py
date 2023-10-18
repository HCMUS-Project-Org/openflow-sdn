# Copyright 2012 James McCauley
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
A super simple OpenFlow learning switch that installs rules for
each pair of L2 addresses.
"""

# These next two imports are common POX convention
from pox.core import core
import pox.openflow.libopenflow_01 as of


# Even a simple usage of the logger is much nicer than print!
log = core.getLogger()


# This table maps (switch,MAC-addr) pairs to the port on 'switch' at
# which we last saw a packet *from* 'MAC-addr'.
# (In this case, we use a Connection object for the switch.)
table = {}


# To send out all ports, we can use either of the special ports
# OFPP_FLOOD or OFPP_ALL.  We'd like to just use OFPP_FLOOD,
# but it's not clear if all switches support this, so we make
# it selectable.
all_ports = of.OFPP_FLOOD


def drop(event):
  # Drops this packet
  msg = of.ofp_packet_out()
  msg.in_port = event.port
  event.connection.send(msg)


# Handle messages the switch has sent us because it has no
# matching rule.
def _handle_PacketIn (event):
  packet = event.parsed

  # Learn the source
  table[(event.connection,packet.src)] = event.port

  dst_port = table.get((event.connection,packet.dst))

  log.debug("--------------------------------------------")
  log.debug("Packet source: %s -- port: %s" % (packet.src, event.port))
  log.debug("Packet dest  : %s -- port: %s" % (packet.dst, dst_port))

  if packet.src == "00:00:00:00:00:01" or dst_port is None:
    # REQUIRE 3: all packet from 'h1'  -> FLOOD
    # We don't know where the destination is yet or this packet from 'h1'.
    # So, we'll just send the packet out all ports (except the one it
    # came in on!) and hope the destination is out there somewhere. :)
    msg = of.ofp_packet_out(data = event.ofp)
    msg.actions.append(of.ofp_action_output(port = all_ports))
    event.connection.send(msg)
    log.debug('>> FLOOD')

  elif packet.dst == "00:00:00:00:00:02" and dst_port != 80:
    # REQUIRE 4: only allow transmit packet to 'h2' when its dst port is 80
    # otherwise, drop this packet
    log.debug('>> H2 - DROP')
    drop(event)

  else:
    # This is the packet that just came in -- we want to
    # install the rule 
    log.debug('>> FLOW MOD')
    msg = of.ofp_flow_mod()
    msg.data = event.ofp # Forward the incoming packet
    msg.match.dl_src = packet.src
    msg.match.dl_dst = packet.dst

    msg.hard_timeout = 20 # REQUIRE 2: every rule has hard_timeout = 20s

    msg.actions.append(of.ofp_action_output(port = dst_port))
    event.connection.send(msg)

    log.debug("Installing %s -> %s" % (packet.src, packet.dst))


def launch (disable_flood = False):
  global all_ports
  if disable_flood:
    all_ports = of.OFPP_ALL

  core.openflow.addListenerByName("PacketIn", _handle_PacketIn)

  log.info("Pair-Learning switch running.")
