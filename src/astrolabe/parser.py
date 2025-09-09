"""TLE parsing utilities"""
from datetime import datetime, timedelta
from typing import Dict, Optional


class TLEParser:
    """Parse TLE data and extract orbital elements"""

    @staticmethod
    def parse_tle(name: str, line1: str, line2: str) -> Optional[Dict]:
        """Parse a TLE into components"""
        try:
            # Line 1
            norad_id = int(line1[2:7])
            classification = line1[7]
            intl_designator = line1[9:17].strip()

            # Epoch year and day
            epoch_year = int(line1[18:20])
            epoch_day = float(line1[20:32])

            # Convert to full year
            if epoch_year < 57:
                year = 2000 + epoch_year
            else:
                year = 1900 + epoch_year

            # Calculate epoch datetime
            epoch = datetime(year, 1, 1) + timedelta(days=epoch_day - 1)

            # Mean motion derivatives
            mean_motion_dot = float(line1[33:43])

            def parse_implied(field8: str) -> float:
                s = field8.replace(' ', '')  # compact but preserve ordering
                # find last sign for exponent (skip mantissa sign if present)
                last_plus = s.rfind('+')
                last_minus = s.rfind('-')
                k = max(last_plus, last_minus)
                if k <= 0 or k == len(s) - 1:
                    # Fallback: treat as zero if malformed
                    return 0.0
                mant_str = s[:k]  # e.g. "-11606" or "49000"
                exp_str = s[k:]  # e.g. "-4" or "-10" or "+5"

                # Build mantissa as 0.<digits> with optional sign
                mant_sign = -1.0 if mant_str.startswith('-') else 1.0
                mant_digits = mant_str.lstrip('+-')
                if not mant_digits.isdigit():
                    return 0.0
                mant = mant_sign * float(f"0.{mant_digits}")

                # Exponent: "+d", "-d", "+dd", "-dd"
                try:
                    exp = int(exp_str)
                except ValueError:
                    exp = 0
                return mant * (10.0 ** exp)

            # Second derivative (if you need it later): line1[44:52]
            # nddot = parse_implied(line1[44:52])

            # BSTAR drag term (1-based cols 54–61 → [53:61], 8 chars)
            bstar = parse_implied(line1[53:61])

            # Line 2
            inclination = float(line2[8:16])
            raan = float(line2[17:25])
            eccentricity = float('0.' + line2[26:33])
            arg_perigee = float(line2[34:42])
            mean_anomaly = float(line2[43:51])
            mean_motion = float(line2[52:63])
            rev_number = int(line2[63:68])

            return {
                'norad_id': norad_id,
                'name': name.strip(),
                'international_designator': intl_designator,
                'epoch': epoch.isoformat(),
                'tle_line1': line1,
                'tle_line2': line2,
                'inclination': inclination,
                'raan': raan,
                'eccentricity': eccentricity,
                'argument_of_perigee': arg_perigee,
                'mean_anomaly': mean_anomaly,
                'mean_motion': mean_motion,
                'revolution_number': rev_number,
                'bstar': bstar,
                'mean_motion_dot': mean_motion_dot,
            }
        except Exception as e:
            print(f"Error parsing TLE for {name}: {e}")
            return None

    @staticmethod
    def validate_checksum(line: str) -> bool:
        """Validate TLE line checksum"""
        checksum = 0
        for char in line[:-1]:
            if char.isdigit():
                checksum += int(char)
            elif char == '-':
                checksum += 1
        return (checksum % 10) == int(line[-1])