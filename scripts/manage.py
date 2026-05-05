#!/usr/bin/env python3
"""
Behemoth infra manager.
Discovers EC2 by project+env tags — no hardcoded IPs or instance IDs.

Usage:
    python scripts/manage.py <project> <env> <on|off|status>

Examples:
    python scripts/manage.py auto-trading staging status
    python scripts/manage.py auto-trading staging off
    python scripts/manage.py auto-trading staging on
"""
import sys
import time
import boto3

REGION = "eu-west-1"
EC2_HOURLY_COST = 0.0116  # t3.micro on-demand eu-west-1


def ec2_client():
    return boto3.client("ec2", region_name=REGION)


def find_instance(project: str, env: str) -> dict:
    ec2 = ec2_client()
    resp = ec2.describe_instances(
        Filters=[
            {"Name": "tag:project", "Values": [project]},
            {"Name": "tag:env",     "Values": [env]},
            {"Name": "instance-state-name", "Values": ["pending", "running", "stopping", "stopped"]},
        ]
    )
    instances = [i for r in resp["Reservations"] for i in r["Instances"]]
    if not instances:
        raise SystemExit(f"No EC2 found with project={project} env={env}")
    return instances[0]


def get_eip(instance_id: str) -> str | None:
    ec2 = ec2_client()
    resp = ec2.describe_addresses(Filters=[{"Name": "instance-id", "Values": [instance_id]}])
    addrs = resp.get("Addresses", [])
    return addrs[0]["PublicIp"] if addrs else None


def cmd_status(project: str, env: str) -> None:
    inst = find_instance(project, env)
    instance_id = inst["InstanceId"]
    state = inst["State"]["Name"]
    name = next((t["Value"] for t in inst.get("Tags", []) if t["Key"] == "Name"), instance_id)
    eip = get_eip(instance_id)

    print(f"\n  {name}")
    print(f"  state:      {state}")
    print(f"  id:         {instance_id}")
    if eip:
        print(f"  ip:         {eip}")
        print(f"  ssh:        ssh -i ~/.ssh/id_ed25519_alejocc ec2-user@{eip}")
    if state == "running":
        launch = inst.get("LaunchTime")
        if launch:
            from datetime import datetime, timezone
            uptime_h = (datetime.now(timezone.utc) - launch).total_seconds() / 3600
            cost = uptime_h * EC2_HOURLY_COST
            print(f"  uptime:     {uptime_h:.1f}h  (${cost:.2f} this session)")
    print()


def cmd_on(project: str, env: str) -> None:
    inst = find_instance(project, env)
    instance_id = inst["InstanceId"]
    state = inst["State"]["Name"]

    if state == "running":
        print(f"  already running: {instance_id}")
        cmd_status(project, env)
        return

    print(f"  starting {instance_id}...")
    ec2_client().start_instances(InstanceIds=[instance_id])

    waiter = ec2_client().get_waiter("instance_running")
    waiter.wait(InstanceIds=[instance_id])
    print("  running")
    cmd_status(project, env)


def cmd_off(project: str, env: str) -> None:
    inst = find_instance(project, env)
    instance_id = inst["InstanceId"]
    state = inst["State"]["Name"]

    if state == "stopped":
        print(f"  already stopped: {instance_id}")
        return

    print(f"  stopping {instance_id}...")
    ec2_client().stop_instances(InstanceIds=[instance_id])

    waiter = ec2_client().get_waiter("instance_stopped")
    waiter.wait(InstanceIds=[instance_id])
    print(f"  stopped — saving ~${EC2_HOURLY_COST * 24:.2f}/day")


COMMANDS = {"on": cmd_on, "off": cmd_off, "status": cmd_status}

if __name__ == "__main__":
    if len(sys.argv) != 4 or sys.argv[3] not in COMMANDS:
        print(__doc__)
        sys.exit(1)
    _, project, env, action = sys.argv
    COMMANDS[action](project, env)
