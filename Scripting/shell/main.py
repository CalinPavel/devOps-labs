#!/usr/bin/env python3

import sys
import shlex
from rich.prompt import Prompt
from rich.console import Console
import requests
from rich.table import Table
import boto3
import json

console = Console()


LAMBDA_URL = "https://p5d2ijbr5tmh4qoegw4khr2q3y0uwzpn.lambda-url.eu-west-3.on.aws/"

def cmd_help(args):
    print("help, hello, lambda, invoke, whoami, exit")

def cmd_hello(args):
    console.print("[bold cyan][*][/] Invoking remote function...")
    try:
        resp = requests.get("https://3p7372hhobkhp25r6y7gfhjpdy0hsfqf.lambda-url.eu-west-3.on.aws/", timeout=15)
        resp.raise_for_status()
    except requests.exceptions.Timeout:
        console.print("[bold red][!][/] Timeout — target not responding.")
        return
    except requests.exceptions.RequestException as e:
        console.print(f"[bold red][!][/] Request failed: {e}")
        return
    
    print(resp.json())

def cmd_lambda(args):
    console.print("[bold cyan][*][/] Invoking remote function...")
    try:
        resp = requests.get(LAMBDA_URL, timeout=15)
        resp.raise_for_status()
    except requests.exceptions.Timeout:
        console.print("[bold red][!][/] Timeout — target not responding.")
        return
    except requests.exceptions.RequestException as e:
        console.print(f"[bold red][!][/] Request failed: {e}")
        return

    try:
        data = resp.json()
    except json.JSONDecodeError:
        console.print("[bold red][!][/] Invalid JSON in response.")
        console.print(resp.text[:500])
        return

    if isinstance(data, list):
        items = data
    else:
        items = data.get("items", [])

    count = len(items)

    console.print(f"[bold green][+][/] {count} records retrieved from target.\n")

    if not items:
        console.print("[yellow]Table is empty.[/]")
        return

    table = Table(title="countries", border_style="green", header_style="bold green")
    keys = list(items[0].keys())
    for key in keys:
        table.add_column(key)

    for item in items:
        table.add_row(*(str(item.get(k, "")) for k in keys))

    console.print(table)


def cmd_whoami(args):
    sts = boto3.client("sts", region_name="eu-west-3")
    ident = sts.get_caller_identity()
    console.print(f"[bold green][+][/] Account: [cyan]{ident['Account']}[/]")
    console.print(f"[bold green][+][/] ARN:     [cyan]{ident['Arn']}[/]")
    console.print(f"[bold green][+][/] UserId:  [cyan]{ident['UserId']}[/]")


def cmd_invoke(args):
    client = boto3.client("lambda", region_name="eu-west-3")
    resp = client.invoke(FunctionName="getData")

    payload = json.loads(resp["Payload"].read())
    print(json.dumps(payload, indent=2)) 


COMMANDS = {
    "help":    (cmd_help,    "show this list"),
    "hello":    (cmd_hello,    "hello"),
    "lambda":  (cmd_lambda,  "lambda - invoke a function"),
    "whoami": ( cmd_whoami, "country info about a country (API)"),
    "invoke": ( cmd_invoke, "invoke hello"),
    "exit":    (None,        "exit - close the session"),
}

def main():
    while True:
        try:
            raw = Prompt.ask("[bold green]root@h4ck3r[/][green]:~$[/]").strip()
        except EOFError:
            break
        if not raw:
            continue

        parts = shlex.split(raw)
        cmd, args = parts[0].lower(), parts[1:]

        if cmd == "exit":
            console.print("[bold red]Disconnecting... Session closed.[/]")
            break
        if cmd not in COMMANDS:
            console.print(f"[red]Unknown command: '{cmd}'. Type 'help'.[/red]")
            continue

        COMMANDS[cmd][0](args)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        console.print("\n[bold red]Out[/]")
        sys.exit(0)