# Benchmarking
This document goes over the methodology and results related to benchmarking `activerecord-batch_touching`.

## Methodology
Nothing *super* scientific here, but just wanted to get a feel for the difference between running with vs. without the batch touching gem.

To do this, we created a brand new Rails 7 app with the following models:

```
class Person < ActiveRecord::Base
  has_many :pets
end

class Pet < ActiveRecord::Base
   belongs_to :person, touch: true
end
```

Used the following scenarios for collecting stats:

- No associations
- x number of records, all with the same parent
- x number of records, all with different parents

Ran each scenario against varying number of records:
- Single touch
- Touch 10 records
- Touch 100 records
- Touch 1000 records

Each test was run 1000 times (100 times for larger record-sets). We used separate runs to calculate the average time elapsed and the average memory used.

### A note about memory tests
Memory results should likely be taken with a grain of salt. To measure "memory used" we disabled garbage collection and used the `GetProcessMem` gem to collect memory usage before and after each test run. However, having GC disabled this isn't representative of what actually happens in production running code! If anything, it just gives us an idea of the size of objects temporarily allocated by each method of touching.

## Results

Overall, the results are fairly close for single touches.  As we have more touches per transaction, the batch touching gem starts to break away in terms of performance. Interestingly, the batch touching gem also uses less memory until we get to 1000s of touches. At 1000s of touches, the batch touching gem uses roughly 2x the memory, but at 7-8x the speed.

### Single touch (no associations), 1000 runs
|  | Average Time (s) | Average Memory (MB) |
|--|--|--|
| Without Batch Touching  | 0.00103 | 0.0199 |
| With Batch Touching  | 0.00105 | 0.0212 |

### Touch 10 records (no associations), 1000 times
|  | Average Time (s) | Average Memory (MB) |
|--|--|--|
| Without Batch Touching  | 0.00723 | 0.125 |
| With Batch Touching  | 0.00175 | 0.0466 |

### Touch 100 records (no associations), 1000 times

|  | Average Time (s) | Average Memory (MB) |
|--|--|--|
| Without Batch Touching  | 0.0684 | 0.922 |
| With Batch Touching  | 0.00768 | 0.435 |

### Touch 1000 records (no associations), 100 times

|  | Average Time (s) | Average Memory (MB) |
|--|--|--|
| Without Batch Touching  | 0.628 | 9.74 |
| With Batch Touching  | 0.0829 | 17.6 |

### Single touch, with parent, 1000 times
|  | Average Time (s) | Average Memory (MB) |
|--|--|--|
| Without Batch Touching  | 0.00226 | 0.0351 |
| With Batch Touching  | 0.00171 | 0.0356 |

### Touch 10 records, all with same parent, 1000 times
|  | Average Time (s) | Average Memory (MB) |
|--|--|--|
| Without Batch Touching  | 0.00789 | 0.162 |
| With Batch Touching  | 0.00273 | 0.0742 |

### Touch 100 records, all with same parent, 1000 times
|  | Average Time (s) | Average Memory (MB) |
|--|--|--|
| Without Batch Touching  | 0.0853 | 1.04 |
| With Batch Touching  | 0.0137 | 0.592 |

### Touch 1000 records, all with same parent, 100 times
|  | Average Time (s) | Average Memory (MB) |
|--|--|--|
| Without Batch Touching  | 0.726 | 10.3 |
| With Batch Touching  | 0.143 | 18.1 |

### Touch 10 records, all with different parent, 1000 times
|  | Average Time (s) | Average Memory (MB) |
|--|--|--|
| Without Batch Touching  | 0.0135 | 0.266 |
| With Batch Touching  | 0.00337 | 0.0917 |

### Touch 100 records, all with different parent, 1000 times
|  | Average Time (s) | Average Memory (MB) |
|--|--|--|
| Without Batch Touching  | 0.159 | 1.31 |
| With Batch Touching  | 0.0171 | 0.943 |

### Touch 1000 records, all with different parent, 100 times
|  | Average Time (s) | Average Memory (MB) |
|--|--|--|
| Without Batch Touching  | 1.43 | 12.9 |
| With Batch Touching  | 0.171 | 34.9 |
