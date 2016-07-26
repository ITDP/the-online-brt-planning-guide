# Design of row and column spans

Let's start with a simple 3x3 table:

```
\begintable
\header  \col foo  \col bar  \col red
\row     \col   1  \col   2  \col   3
\row     \col   4  \col   5  \col   6
\row     \col   7  \col   8  \col   9
\endtable
```

This should render like:

| foo | bar | red |
|-----|-----|-----|
|   1 |   2 |   3 |
|   4 |   5 |   6 |
|   7 |   8 |   9 |

So far so good.  How about if we were to merge some cells?  How should this
look like in a language syntax that is both clean and easy to use?


## First attempt: statefull extension, a la, HTML

### Example 1: (1), (2,3), (4,7), (5,6,8,9)

```
\begintable
\header  \col foo  \col bar  \col red
\row  \col 1  \colspan{2} 2,3
\row  \rowspan{2} 4  \multispan{2}{2} 5,6,7,8
\endtable
```

### Example 2: only merge (1,4)

```
\begintable
\header  \col foo  \col bar  \col red
\row  \rowspan{2} 1,4  \col   2  \col   3
\row                   \col   5  \col   6
\row  \col 7           \col   8  \col   9
\endtable
```

### Example 3: only merge (2,5)

```
\begintable
\header  \col foo  \col bar  \col red
\row  \col 1  \rowspan{2} 2,5  \col 3
\row  \col 4                   \col 6
\row  \col 7  \col 8           \col 9
\endtable
```

### Example 4: make things weird with a disappearing `\row`

```
\begintable
\header  \col foo  \col bar  \col red
\row  \multispan{2},{3} 1,2,3,4,5,6
\row  \col 7  \col 8  \col 9
\endtable
```

### Notes

This will surely be hard to implement.

Also, it makes for somewhat weird, verbose and fragile syntax.


## Second attempt: still statefull, but spanned cells must be skipped

Other changes experimented here: shorter and simpler command names, since table
commands are (so far) the third most used token throughout the guide.

### Example 1

```
\begintable
\header  \col foo       \col bar              \col red
\row     \col 1         \cspan{2} 2,3         \skip
\row     \rspan{2} 1,4  \mspan{2}{2} 5,6,7,8  \skip
\row     \skip          \skip                 \skip
\endtable
```

### Example 2

```
\begintable
\header  \col foo       \col bar  \col red
\row     \rspan{2} 1,4  \col   2  \col   3
\row     \skip          \col   5  \col   6
\row     \col 7         \col   8  \col   9
\endtable
```

### Example 3

```
\begintable
\header  \col foo  \col bar       \col red
\row     \col 1    \rspan{2} 2,5  \col 3
\row     \col 4    \skip          \col 6
\row     \col 7    \col 8         \col 9
\endtable
```

### Example 4

```
\begintable
\header  \col foo                  \col bar  \col red
\row     \mspan{2}{3} 1,2,3,4,5,6  \skip     \skip
\row     \skip                     \skip     \skip
\row     \col 7                    \col 8    \col 9
\endtable
```

### Example 5: alternate syntax (no `\skip`, just `\col`)

```
\begintable
\header  \col foo      \col bar           \col red
\row     \col 1        \cspan{2} 2,       \col 3
\row     \rspan{2} 1,  \mspan{2}{2} 5,6,  \col
\row     \col 4        \col               \col 7,8
\endtable
```

But this alternate syntax fails to work with vlist cells.


## Separator syntax, instead of command syntax

This is more about general table syntax than of table cell spans.

A separator syntax could reduce the number of `\col` (or `\c`) tokens by
`1*rows*tables`.

Independently, the smaller `\c` instead of `\col` could reduce the number of
typed chars by (at least) `2*columns*rows*tables`

Before:

```
\begintable
\header  \col foo       \col bar              \col red
\row     \col 1         \cspan{2} 2,3         \skip
\row     \rspan{2} 1,4  \mspan{2}{2} 5,6,7,8  \skip
\row     \skip          \skip                 \skip
\endtable
```

After:

```
\begintable
\header
foo            \c bar                \c red  \lf  \' this \lf is optional, cound be infered by \data '\
\data
1              \cspan{2} 2,3         \skip   \lf
\rspan{2} 1,4  \mspan{2}{2} 5,6,7,8  \skip   \lf
\skip          \skip                 \skip   \lf  \' this \lf is optional, could be infered by \endtable '\
\endtable
```

On another example we go from:

```
\begintable
\header
\row  \rspan{2} Name   \cspan{2} Cost  \skip
\row  \skip            \col Fixed      \col Marginal
\data
\row  \col Bus         \col 33.4       \col 5.2
\row  \col Metro       \col 290        \col 4.6
\row  \col Hoverboard  \col 1.2        \col 12.3
\endtable
```

to:

```
\begintable
\header
\rspan{2} Name  \cspan{2} Cost  \skip        \lf
\skip           \c Fixed        \c Marginal  \lf
\data
Bus             \c 33.4         \c 5.2       \lf
Metro           \c 290          \c 4.6       \lf
Hoverboard      \c 1.2          \c 12.3      \lf
\endtable
```

While having two separate sections `\header` and `\row` already solves on issue
(multi-row headers), the rest obviously doesn't maintain it's beauty when we
add first column spans.

Going back to Solution 2 + extended header–data syntax + shorter command names,
we go from (279 chars):

```
\begintable
\header
\row  \rspan{2} Name   \cspan{2} Cost  \skip
\row  \skip            \col Fixed      \col Marginal
\data
\row  \col Bus         \col 33.4       \col 5.2
\row  \col Metro       \col 290        \col 4.6
\row  \col Hoverboard  \col 1.2        \col 12.3
\endtable
```

to (251 chars, 10% reduction):

```
\begintable
\header
\r \rspan{2} Name  \cspan{2} Cost  \skip
\r \skip           \c Fixed        \c Marginal
\data
\r \c Bus          \c 33.4         \c 5.2
\r \c Metro        \c 290          \c 4.6
\r \c Hoverboard   \c 1.2          \c 12.3
\endtable
```


## Notes

This is an improvement.  Keep this in mind, and go over other ways to improve
general table input in the guide.

Next steps:

 - study the actual performance and restrictions of `html` `colspan` and
   `tablespan` attributes;
 - study how to best implement spans on TeX, particularly of rowspans

