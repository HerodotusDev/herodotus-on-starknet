#[cfg(test)]
mod binary_search {
    use option::OptionTrait;
    use core::array::{ArrayTrait, SpanTrait};
    use traits::{Into, TryInto, PartialOrd};
    use debug::PrintTrait;

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
            continue;
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

        if low_val <= x && high_val <= x {
            if low_val > high_val {
                return Option::Some(low);
            }
            return Option::Some(high);
        }

        if high_val <= x {
            return Option::Some(high);
        }
        return Option::Some(low);
    }

    #[available_gas(9999999)]
    #[test]
    fn test_binary_search_no_element() {
        let mut arr = ArrayTrait::new();
        let arr_span = arr.span();

        assert(binary_search(arr_span, 43, Option::Some(false)).is_none(), 'Unexpected result');
        assert(binary_search(arr_span, 43, Option::Some(true)).is_none(), 'Unexpected result');
    }

    #[available_gas(9999999)]
    #[test]
    fn test_binary_search_single_element() {
        let mut arr = ArrayTrait::new();
        arr.append(42);

        let arr_span = arr.span();

        // Exact match -> index retrieval:
        assert(binary_search(arr_span, 42, Option::Some(false)).unwrap() == 0, 'Unexpected result');
        assert(binary_search(arr_span, 43, Option::Some(false)).is_none(), 'Unexpected result');

        // Closest to x -> index retrieval:
        assert(binary_search(arr_span, 43, Option::Some(true)).unwrap() == 0, 'Unexpected result');
    }

    #[available_gas(9999999)]
    #[test]
    fn test_binary_search_many_elements() {
        let mut arr = ArrayTrait::new();
        arr.append(1);
        arr.append(2);
        arr.append(3);
        arr.append(4);
        arr.append(5);

        let arr_span = arr.span();

        // Exact match -> index retrieval:
        assert(
            binary_search(arr_span, 1, Option::Some(false)).unwrap() == 0, 'Unexpected result'
        );
        assert(
            binary_search(arr_span, 2, Option::Some(false)).unwrap() == 1, 'Unexpected result'
        );
        assert(
            binary_search(arr_span, 3, Option::Some(false)).unwrap() == 2, 'Unexpected result'
        );
        assert(
            binary_search(arr_span, 4, Option::Some(false)).unwrap() == 3, 'Unexpected result'
        );
        assert(
            binary_search(arr_span, 5, Option::Some(false)).unwrap() == 4, 'Unexpected result'
        );
        assert(binary_search(arr_span, 6, Option::Some(false)).is_none(), 'Unexpected result');

        // Closest to x -> index retrieval:
        assert(binary_search(arr_span, 1, Option::Some(true)).unwrap() == 0, 'Unexpected result');
        assert(binary_search(arr_span, 2, Option::Some(true)).unwrap() == 1, 'Unexpected result');
        assert(binary_search(arr_span, 3, Option::Some(true)).unwrap() == 2, 'Unexpected result');
        assert(binary_search(arr_span, 4, Option::Some(true)).unwrap() == 3, 'Unexpected result');
        assert(binary_search(arr_span, 5, Option::Some(true)).unwrap() == 4, 'Unexpected result');
        assert(binary_search(arr_span, 6, Option::Some(true)).unwrap() == 4, 'Unexpected result');
        assert(binary_search(arr_span, 0, Option::Some(true)).unwrap() == 0, 'Unexpected result');
    }

    #[available_gas(9999999)]
    #[test]
    fn text_binary_search_many_elements_with_gaps() {
        let mut arr = ArrayTrait::new();
        arr.append(3);
        arr.append(8);
        arr.append(9);
        arr.append(14);

        let arr_span = arr.span();

        // Exact match for array with gaps
        assert(binary_search(arr_span, 2, Option::Some(false)).is_none(), 'Unexpected result 1');
        assert(binary_search(arr_span, 3, Option::Some(false)).unwrap() == 0, 'Unexpected result 2');
        assert(binary_search(arr_span, 4, Option::Some(false)).is_none(), 'Unexpected result 3');
        assert(binary_search(arr_span, 7, Option::Some(false)).is_none(), 'Unexpected result 4');
        assert(binary_search(arr_span, 8, Option::Some(false)).unwrap() == 1, 'Unexpected result 5');
        assert(binary_search(arr_span, 9, Option::Some(false)).unwrap() == 2, 'Unexpected result 6');
        assert(binary_search(arr_span, 10, Option::Some(false)).is_none(), 'Unexpected result 7');
        assert(binary_search(arr_span, 13, Option::Some(false)).is_none(), 'Unexpected result 8');
        assert(binary_search(arr_span, 14, Option::Some(false)).unwrap() == 3, 'Unexpected result 9');
        assert(binary_search(arr_span, 15, Option::Some(false)).is_none(), 'Unexpected result 10');

        // Closest to x
        assert(binary_search(arr_span, 2, Option::Some(true)).unwrap() == 0, 'Unexpected result a');
        assert(binary_search(arr_span, 3, Option::Some(true)).unwrap() == 0, 'Unexpected result b');
        assert(binary_search(arr_span, 4, Option::Some(true)).unwrap() == 1, 'Unexpected result c');
        assert(binary_search(arr_span, 7, Option::Some(true)).unwrap() == 1, 'Unexpected result');
        assert(binary_search(arr_span, 8, Option::Some(true)).unwrap() == 1, 'Unexpected result');
        assert(binary_search(arr_span, 9, Option::Some(true)).unwrap() == 2, 'Unexpected result');
        assert(binary_search(arr_span, 10, Option::Some(true)).unwrap() == 3, 'Unexpected result');
        assert(binary_search(arr_span, 13, Option::Some(true)).unwrap() == 3, 'Unexpected result');
        assert(binary_search(arr_span, 14, Option::Some(true)).unwrap() == 3, 'Unexpected result');
        assert(binary_search(arr_span, 15, Option::Some(true)).unwrap() == 3, 'Unexpected result');
    }
}
