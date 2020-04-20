module fuzzyd.core;

import std.stdio;
import std.array;
import std.container.rbtree;
import std.container.binaryheap;
import std.ascii;
import std.math;
import std.conv;
import std.algorithm.iteration;

alias fuzzyFn =  FuzzyResult[]delegate(string);
alias bonusFn = double function(Input);

private:
struct Input
{
    string input;
    string pattern;
    int col;
    int row;
    double[][] scoreMatrix;

    char inputAtIndex()
    {
        return input[row];
    }

    char patternAtIndex()
    {
        return pattern[col];
    }

    bool isMatch()
    {
        return toLower(inputAtIndex) == toLower(patternAtIndex);
    }

    bool isCaseSensitiveMatch()
    {
        return isUpper(inputAtIndex) && isUpper(patternAtIndex) && isMatch;
    }
}

double previousCharBonus(Input input)
{
    return (input.col > 0 && input.row > 0) ? 2.5 * input.scoreMatrix[input.row - 1][input.col - 1]
        : 0;
}

double startBonus(Input input)
{
    return (input.col == 0 && input.row == 0) ? 1 : 0;
}

double caseMatchBonus(Input input)
{
    return input.isCaseSensitiveMatch ? 1.5 : 0;
}

double wordBoundaryBonus(Input input)
{
    const isInputAt = input.row == 0 || input.row == input.input.length - 1
        || isWhite(input.input[input.row - 1]) || isWhite(input.input[input.row + 1]);
    return isInputAt ? 1.2 : 0;
}

public:

/// fuzzy search result
struct FuzzyResult
{
    string value; //// entry. e.g "Documents/foo/bar/"
    double score; //// similarity metric. (Higher better)
    RedBlackTree!(int, "a < b", false) matches; //// index of matched characters.
}

/**
 * Fuzzy search
 * Params:
 *   db = Array of string containing the search list.
 * Examples:
 * --------------------
 * fuzzy(["foo", "bar", "baz"])("br");
 * // => [FuzzyResult("bar", 5, [0, 2.3]), FuzzyResult("baz", 3, [0]), FuzzyResult("foo", 0, [])]
 * --------------------
 */
fuzzyFn fuzzy(string[] db)
{

    bonusFn[] bonusFns = [
        &previousCharBonus, &startBonus, &caseMatchBonus, &wordBoundaryBonus
    ];

    double charScore(Input input)
    {
        return input.isMatch ? reduce!((acc, f) => acc + f(input))(1.0, bonusFns) : 0;
    }

    FuzzyResult score(string input, string pattern)
    {
        double score = 0;
        double simpleMatchScore = 0;
        double[][] scoreMatrix = new double[][](input.length, pattern.length);
        auto matches = redBlackTree!int();

        for (int col = 0; col < pattern.length; col++)
        {
            for (int row = 0; row < input.length; row++)
            {
                const charScore = charScore(Input(input, pattern, col, row, scoreMatrix));
                if (charScore > 0)
                    matches.insert(row);
                if (charScore is 1.0)
                    simpleMatchScore += 1;
                else
                    score += charScore;
                scoreMatrix[row][col] = charScore;
            }
        }

        const totalScore = score + (simpleMatchScore / 2.0);
        return FuzzyResult(input, totalScore, matches);
    }

    FuzzyResult[] search(string pattern)
    {
        auto maxpq = BinaryHeap!(FuzzyResult[], "a.score < b.score")(new FuzzyResult[db.length], 0);
        foreach (e; db)
        {
            maxpq.insert(score(e, pattern));
        }
        return maxpq.array();
    }

    return &search;
}
