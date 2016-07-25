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

## Notes

This is an improvement.  Keep this in mind, and go over other ways to improve
general table input in the guide.

