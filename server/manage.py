#!/usr/bin/env python
import os, sys
def main():
    # Aggiungi la cartella src al Python path
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'settings')
    from django.core.management import execute_from_command_line
    execute_from_command_line(sys.argv)
if __name__ == '__main__':
    main()
