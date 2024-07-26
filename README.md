# TimestampIt reference scripts

This is a collection of scripts and programs in various languages for creating and verifying
Trusted Timestamps on https://www.timestampit.com.

## Organization

Scripts are organized into folders named based on their language or utility.

There are two basic operations involving Trusted Timestamps: Creation and Verification. Therefore, each folder generally contains two scripts: one for creating Trusted Timestamps, and another for verifying them.

## Usage

Generally, each script can be run without any arguments to get a usage statement:

```
./sh/create.sh
usage: ./sh/create.sh <file to timestamp> <timestampit username>
```

Some scripts have a usage statement and a few options:

```
$ ./rb/create.rb --help
Usage: ./rb/create.rb [options] <file to timestamp> <username> <password>
    -h, --host hostname              Timestampit host to use
    -o, --output filename            Filename to save the new Trusted Timestamp to
    -v, --[no-]verbose               Run verbosely
```

Certain scripts do have dependencies. For example, before running the Python scripts in `/py`, you will need to install the dependencies which can be done via:

```
$ pip3 install -r py/requirements.txt
```

## Take this code and build awesome things!

We encourage building new applications that make use of Trusted Timestamps. This code can be copy and pasted into any project to be used as a starting point.

