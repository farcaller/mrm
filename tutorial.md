# MRM tutorial

## Installation

Download the binary from the [latest release
page](https://github.com/farcaller/mrm/releases/tag/latest).

## Basic config file

Create a text file named `basic.yaml`. First, add the authentication section:

```yaml
authInfo:
  username: "cool_dragon"
  password: "Secr3t!passw0rd"
  characterName: "Mighty Flapper"
  characterSurname: "Derp"
```

You need to type your username and password in plain text exactly as you type
them at the login screen. The character name and surname you use will select the
character that **must** own the rooms you're about to modify.

Next section is optional, but highly recommended:

```yaml
defaultExitMessages:
  leave: leaves to the $SHORT.
  arrive: arrives from the $SHORT.
  travel: goes to the $SHORT.
```

It provides the default messages for the exits, unless otherwise specified. The
exits can have special strings: `$NAME` and `$SHORT` that are discussed further
below.

Now to add a couple rooms to mrm, first create them in Wolfery:

```
create room
get room id
create room
get room id
```

And then add it to the new `rooms` section in the config:

```yaml
rooms:
- tid: demo room
  id: cbe_blah_something_id_from_above
  name: The Demo Room
  exitName: Demo
  description: >
    Write the description here. Mind that you need to have two empty lines in
    yaml for them to become a single empty line.


    So you make paragraphs like this.


    [[And you add extra]]


    For the headers, too.
  exits:
  - to: '#bv4b0ogt8749qsg77l9g'
    name: Station Park
    keywords: [park, back]
  - to: other room
- tid: other room
  id: cbe_blah_something_id_from_above
  name: Other Room
  description: >
    This is just the other room.
  exits:
  - back: demo room

```

Let's go through those keys. `tid` is the room's "text id" and it's how you
refer to this room everywhere in MRM. Try not to change it needlessly to reduce
confusion.

`id` is the room id as returned from Wolfery. MRM cannot create rooms on its own
so you must first create the room and get its id for MRM to be able to sync it.

`name` and `description` are the same as in wolfery. `exitName` is optional and
that's a short name for this room that can be used in the exit messages. The
`$SHORT` thing from before? It's replaced by whatever is in `exitName` (or
`name` if there's no `exitName` specified). `$NAME` is always replaced by the
full `name`.

Let's take a closer look at the exits.

```yaml
  - to: other room
```

Is a straightforward exit to _Other Room_. Whenever you use `to:` you need to
specify either the other room's `tid`, or the wolfery's room id prefixed with
`#` (you will also have to put that one in double quotes).

MRM will automatically use the room's `name` as the exit name and the room's
`tid` as the exit keyword. Of course, you can override that with a `name:` and
`keywords:` properties as seen here:

```yaml
  - to: '#bv4b0ogt8749qsg77l9g'
    name: Station Park
    keywords: [park, back]
```

You can use `back` instead of `to` for the back exits. This will prepend the
_back_ keyword automatically to the list but otherwise will behave as `to`. In
the example above the single exit from _Other Room_ will be named _The Demo
Room_ and will have two keywords: _back_ and _demo room_.

For even more advanced use, you can specify `designatedExits` on the room:

```yaml
- tid: demo room
  id: cbe_blah_something_id_from_above
  name: The Demo Room
  ...
  designatedExits: [shrine, scary]
```

If present, those keywords will be added to any exit that links to this room.

## Verifying the changes

Run the following command:

```
mrm.exe lint -s basic.yaml
```

It will verify various common issues and typos and provide you with a report.

Now run the sync:

```
mrm.exe sync -s basic.yaml
```

This will cause MRM to connect to wolfery and actually teleport around the
rooms, learn the layout and provide you with the list of changes that must be
done to make the config authoritative.

If you're happy with the output above run:

```
mrm.exe sync -s basic.yaml --apply
```

To commit your changes to wolfery.

All of those commands support an extra argument, `-r tid` to lint/sync only one
room.
