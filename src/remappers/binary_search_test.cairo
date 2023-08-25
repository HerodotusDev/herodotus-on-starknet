#[cfg(test)]
mod binary_search {
    use option::OptionTrait;
    use core::array::{ArrayTrait, SpanTrait};
    use traits::{Into, TryInto, PartialOrd};

    fn binary_search(arr: Span<u256>, x: u256, get_closest: Option<bool>) -> Option<u256> {
        let arr_len: u256 = arr.len().into();
        if arr_len == 0 {
            return Option::None(());
        }

        let mut low: u256 = 0;
        let mut high: u256 = arr_len - 1;

        let result = loop {
            if low > high {
                break Option::None(());
            }

            let mid: u256 = (low + high) / 2;
            let mid_val: u256 = *arr.at(mid.try_into().unwrap());
            if mid_val == x {
                break Option::Some(mid);
            }
            if mid_val < x {
                low = mid + 1;
            } else {
                if mid == 0 {
                    break Option::None(());
                }
                high = mid - 1;
            }
            low = low;
        };

        match result {
            Option::Some(_) => result,
            Option::None(_) => {
                if get_closest.unwrap() == true {
                    closest_from_x(arr, low, high, x)
                } else {
                    result
                }
            }
        }
    }

    fn closest_from_x(arr: Span<u256>, low: u256, high: u256, x: u256) -> Option<u256> {
        let arr_len: u256 = arr.len().into();
        if low >= arr_len {
            return Option::Some(high);
        }
        if high < 0 {
            return Option::Some(low);
        }
        let low_val: u256 = *arr.at(low.try_into().unwrap());
        let high_val: u256 = *arr.at(high.try_into().unwrap());

        let mut a = 0;
        if low_val > x {
            a = low_val - x;
        } else {
            a = x - low_val;
        }

        let mut b = 0;
        if high_val > x {
            b = high_val - x;
        } else {
            b = x - high_val;
        }

        if a < b {
            return Option::Some(low);
        }

        return Option::Some(high);
    }

    #[available_gas(9999999)]
    #[test]
    fn test_binary_search() {
        let mut arr = ArrayTrait::new();
        arr.append(1);
        arr.append(2);
        arr.append(3);
        arr.append(4);
        arr.append(5);

        let arr_span = arr.span();

        // Exact match -> index retrieval:
        assert(binary_search(arr_span, 1, Option::Some(false)).unwrap() == 0, 'Unexpected result');
        assert(binary_search(arr_span, 2, Option::Some(false)).unwrap() == 1, 'Unexpected result');
        assert(binary_search(arr_span, 3, Option::Some(false)).unwrap() == 2, 'Unexpected result');
        assert(binary_search(arr_span, 4, Option::Some(false)).unwrap() == 3, 'Unexpected result');
        assert(binary_search(arr_span, 5, Option::Some(false)).unwrap() == 4, 'Unexpected result');
        assert(binary_search(arr_span, 6, Option::Some(false)).is_none(), 'Unexpected result');

        // Closest to x -> index retrieval:
        assert(binary_search(arr_span, 6, Option::Some(true)).unwrap() == 4, 'Unexpected result');
        assert(binary_search(arr_span, 1, Option::Some(true)).unwrap() == 0, 'Unexpected result');
        assert(binary_search(arr_span, 2, Option::Some(true)).unwrap() == 1, 'Unexpected result');
        assert(binary_search(arr_span, 3, Option::Some(true)).unwrap() == 2, 'Unexpected result');
        assert(binary_search(arr_span, 4, Option::Some(true)).unwrap() == 3, 'Unexpected result');
        assert(binary_search(arr_span, 5, Option::Some(true)).unwrap() == 4, 'Unexpected result');
        assert(binary_search(arr_span, 6, Option::Some(true)).unwrap() == 4, 'Unexpected result');
        assert(binary_search(arr_span, 0, Option::Some(true)).unwrap() == 0, 'Unexpected result');
    }
}
