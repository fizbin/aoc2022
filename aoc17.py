from aoc_util import *
import re
import numpy as np
import heapq
import itertools
import copy

# # is 2
# @ is 1
# . is 0


def get_entry_point(grid):
    gridshape = np.shape(grid)
    rowcoord = np.reshape(np.arange(gridshape[0]), (gridshape[0], 1))
    floor = np.where(grid, rowcoord, -1).max()
    return (int(floor) + 4, 2)


def overlay(shape, grid, offset):
    (offr, offc) = offset
    shape_shape = np.shape(shape)
    grid[offr : offr + shape_shape[0], offc : offc + shape_shape[1]] = shape


def moveleft(grid):
    if not (grid == 1).any():
        return False
    if (grid[..., 0] == 1).any():
        return False
    rolled_left = np.roll(grid, -1, 1)
    if ((rolled_left == 1) & (grid == 2)).any():
        return False
    grid[:] = np.where((grid == 1) | (rolled_left == 1), rolled_left % 2, grid)
    return True


def moveright(grid):
    if not (grid == 1).any():
        return False
    if (grid[..., -1] == 1).any():
        return False
    rolled_right = np.roll(grid, 1, 1)
    if ((rolled_right == 1) & (grid == 2)).any():
        return False
    grid[:] = np.where((grid == 1) | (rolled_right == 1), rolled_right % 2, grid)
    return True


def movedown(grid):
    if not (grid == 1).any():
        return False
    if (grid[0, ...] == 1).any():
        return False
    rolled_down = np.roll(grid, -1, 0)
    if ((rolled_down == 1) & (grid == 2)).any():
        return False
    grid[:] = np.where((grid == 1) | (rolled_down == 1), rolled_down % 2, grid)
    return True


data = get_data_lines(17)[0].strip()

# data = '>>><<><>><<<>><>>><<<>>><<<><<<>><>><<>>'

shapespec = """####

.#.
###
.#.

###
..#
..#

#
#
#
#

##
##""".split(
    "\n\n"
)

shapes_as_strlists = [s.splitlines() for s in shapespec]
shapes_as_numlists = [
    [list(int(x == "#") for x in l) for l in s] for s in shapes_as_strlists
]

shapes = [np.array(s, dtype=np.uint8) for s in shapes_as_numlists]

grid = np.zeros((6000, 7), dtype=np.uint8)

showx = {0: ".", 1: "@", 2: "#"}

seenoffsat = {}
seenatoffs = {}
p2ans = []

jetidx = 0
for pieceidx in range(2022):
    shape = shapes[pieceidx % 5]
    overlay(shape, grid, get_entry_point(grid))
    lroff = 0
    while True:
        jetdir = data[jetidx % len(data)]
        jetidx += 1
        # if pieceidx == 38:
        #     for r in reversed(range(60, 75)):
        #         print("1: " + ''.join(showx[grid[r][c]] for c in range(7)))
        #     print()
        if jetdir == "<":
            if moveleft(grid):
                lroff -= 1
        else:
            if moveright(grid):
                lroff += 1
        # if pieceidx == 38:
        #     for r in reversed(range(60, 75)):
        #         print("2: " + ''.join(showx[grid[r][c]] for c in range(7)))
        #     print()
        if not movedown(grid):
            break
        # if pieceidx == 38:
        #     for r in reversed(range(60, 75)):
        #         print("3: " + ''.join(showx[grid[r][c]] for c in range(7)))
        #     print()
        # sys.exit()
    grid = np.where(grid > 0, 2, 0)
    currheight = get_entry_point(grid)[0] - 3
    # print("!", pieceidx, jetidx % len(data), pieceidx % 5, currheight)
    # if pieceidx in (37,38):
    #     for r in reversed(range(60, 75)):
    #         print(''.join(showx[grid[r][c]] for c in range(7)))
    if (jetidx % len(data), pieceidx % 5, lroff) in seenoffsat:
        oldpieceidx = seenoffsat[(jetidx % len(data), pieceidx % 5, lroff)]
        patlen = pieceidx - oldpieceidx
        # print(f"patlen {patlen} found at {pieceidx} now {currheight} then {seenatoffs[oldpieceidx]}")
        njumps = (1000000000000 - pieceidx) // patlen
        heightgain1 = njumps * (currheight - seenatoffs[oldpieceidx])
        heightgain2 = (
            seenatoffs[oldpieceidx + (1000000000000 - pieceidx) % patlen]
            - seenatoffs[oldpieceidx]
        )
        # a list because we detect a loop prematurely. Make sure we only take
        # the answer from far enough to have a real loop
        p2ans.append(currheight + heightgain1 + heightgain2)
    seenoffsat[(jetidx % len(data), pieceidx % 5, lroff)] = pieceidx
    seenatoffs[pieceidx] = currheight


print(get_entry_point(grid)[0] - 3)
print(p2ans[-1])