#!/usr/bin/env python3

import sys
import shlex
from rich.prompt import Prompt
from rich.console import Console

console = Console()

def cmd_help(args):
    print("Options: help scan lambda country exit")

def cmd_scan(args):
    print("Options: help scan lambda country exit")

def cmd_lambda(args):
    print("Options: help scan lambda country exit")

def cmd_country(args):
    print("Options: help scan lambda country exit")


COMMANDS = {
    "help":    (cmd_help,    "show this list"),
    "scan":    (cmd_scan,    "scan [limit] - scan the DynamoDB table"),
    "lambda":  (cmd_lambda,  "lambda <name> - invoke/simulate a function"),
    "country": (cmd_country, "country <name> - info about a country (API)"),
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