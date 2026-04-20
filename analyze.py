import subprocess
try:
    stdout = subprocess.check_output(
        ['C:\\flutter\\bin\\dart.bat', 'analyze', '--format=machine'],
        stderr=subprocess.STDOUT, shell=True
    )
    print(stdout.decode('utf-8', errors='ignore'))
except subprocess.CalledProcessError as e:
    print(e.output.decode('utf-8', errors='ignore'))
