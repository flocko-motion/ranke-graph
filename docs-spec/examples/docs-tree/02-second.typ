#import "vocabulary.typ": *

= A chapter using the manual constructs <ch:second>

Every construct in the *manual* group is called below. These are the ones a
chapter gains over a paper.

#lorem(35)

== Telling the reader something <sec:admonitions>

#note[#lorem(24)]

#lorem(20)

#warning[#lorem(26)]

There are two levels and only two. A note is worth knowing and costs nothing to
read past; a warning is something the reader can lose or break.

== Describing named things <sec:reference>

`item` is the workhorse of reference documentation — a flag, a configuration
key, an API field, each with its signature and what it does:

#item("--some-flag")[
  #lorem(16)
]

#item("config.some_key")[
  #lorem(20)
]

#item("someFunction(argument, option: none)")[
  #lorem(14)
]

== Showing a case <sec:examples>

#example[#lorem(24)]

#example(title: "with a title")[#lorem(18)]
