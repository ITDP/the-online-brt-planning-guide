# List design

## Simple lists

Obvious solutions are to use a `\item` mark or a markdown based space + mark:

```
\item foo
\item bar
```

```
 - foo
 - bar
```

Both are legible enough, but depending on whitespace and common characters like
hyphens is quite error-prone.

The command based solution seems better, so let's move in that direction.


## Nested lists

Simply nesting `\item` command with nothing else would need to depend on
whitespace, and that's bad.

```
\item foo
\item bar
	\item red
	\item blu
\item rab
```

Alternatives are to add (maybe optional) `\beginlist` and `\endlist` commands

```
\item foo
\item bar
	\beginlist
	\item red
	\item blu
	\endlist
\item rab
```

or to use (maybe optional) braces (`{}`) to delimit vertical nesting

```
\item foo
\item{
	bar
	\item red
	\item blu
}
\item rab
```


## Vertical lists as items in general

Braces also solve the issue of general vertical lists as items, such as multi-par items

```
\item foo
\item{
	red

	blu
}
\item bar
```

and make `\beginlist` and `\endlist` unnecessary, since lists can simply break
on the first vertical break found.


## Homogeneity with other constructs

Since required command arguments have been elsewhere wrapped in braces too, it
might be interesting to adopt brackets (`[]`) as _optional_ argument indicators.

Thus, the nested list example becomes

```
\item foo
\item[
	bar
	\item red
	\item blu
]
\item rab
```

and still remains quite legible.


## Shorter/cleaner syntax experiments

Shortening the command name from `\item` to `\i` makes the syntax obscure and doesn't work:

```
\i foo
\i[
	bar
	\i red
	\i blu
]
\i rab
```

Using (or allowing) reserved charactesr to function as the item mark also don't work:

```
@ foo
@[
	bar
	@ red
	@ blu
]
@ rab
```


## Comparison to markdown

Despite being a bit more verbose, the proposed solution

```
\item foo
\item[
	bar
	\item red
	\item blu
]
\item rab
```

seems equally as legible as markdown

```
 - foo
 - bar
    + red
    + blu
 - rab
```

even with little nesting, and certainly scales better since it does not depend
(or impact) on whitespace.

