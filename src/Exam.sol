// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Exam {
    enum QuestionType {
        RESERVE, // reserved for future use
        MULTIPLE_CHOICE, // 1 byte
        ANSWER_32,  // 32 byte
        ANSWER_64 // 64 byte (future support)
    }

    // owner
    address public owner;

    // meta data
    uint256 public number;
    string public title;
    string public description;
    // the score to pass this exam
    // The maximum score is equal to uint8 max value -> 255
    uint8 public passScore;

    // submit time
    uint64 public submitStartTime;
    uint64 public submitEndTime;

    // question
    // concatenated bytes array of `QuestionType`, each QuestionType consumes 1 byte
    bytes public questionTypes;
    bytes public questions;

    // correct answer
    bytes32 public correctAnswerHash;
    // concatenated bytes array of correct answers, each answer consumes the length defined by questionTypes
    bytes public corrects;
    bytes public points; // concatenated bytes array of each answer's points, each point consumes 1 byte
    bytes public pointsMultiplier;

    // answer
    mapping(address => bytes) public answerMap; // concatenated bytes array of answers
    mapping(address => bytes32) public answerHashMap;
    mapping(address => uint8) public scoreMap;

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function init(
        string calldata title_,
        string calldata description_,
        uint64 submitStartTime_,
        uint64 submitEndTime_,
        uint8 passScore_
    ) public onlyOwner {
        title = title_;
        description = description_;
        submitStartTime = submitStartTime_;
        submitEndTime = submitEndTime_;
        passScore = passScore_;
    }

    /**
     * @param questionTypes_ 2 bits array of `QuestionType`
     * @param questions_ encoded questions
     * @param correctAnswerHash_ hash of correct answers bytes array
     */
    function revealQuetion(
        bytes calldata questionTypes_,
        bytes calldata questions_,
        bytes32 correctAnswerHash_
    ) public onlyOwner {
        questionTypes = questionTypes_;
        questions = questions_;
        correctAnswerHash = correctAnswerHash_;
    }

    /**
     * @param answerHash hash of answers bytes array
     */
    function submitAnswer(
        bytes32 answerHash
    ) public {
        answerHashMap[msg.sender] = answerHash;
    }

    /**
     * @param corrects_ correct answers bytes array
     * @param points_ 8 bits array of points
     * @param pointsMultiplier_ 8 bits array of points multiplier
     */
    function revealCorrects(
        bytes calldata corrects_,
        bytes calldata points_,
        bytes calldata pointsMultiplier_
    ) public onlyOwner {
        // assure that the hash of corrects is equal to correctAnswerHash
        require(keccak256(corrects_) == correctAnswerHash, "invalid corrects");

        corrects = corrects_;
        points = points_;
        pointsMultiplier = pointsMultiplier_;
    }

    /**
     * @param answers_ answers bytes array
     */
    function calculateScore(
        bytes calldata answers_
    ) public returns (uint8 score) {
        // assure that the hash of answers is equal to answerHashMap[msg.sender]
        require(keccak256(answers_) == answerHashMap[msg.sender], "invalid answers");

        uint256 questionIndex = 0;
        uint256 answerIndex = 0;
        bytes memory answers = answerMap[msg.sender];

        for (uint256 i = 0; i < questionTypes.length; i++) {
            QuestionType qType = QuestionType(uint8(questionTypes[i]));

            uint256 answerLength;
            if (qType == QuestionType.MULTIPLE_CHOICE) {
                answerLength = 1; // 8 bits
            } else if (qType == QuestionType.ANSWER_32) {
                answerLength = 32; // 256 bits
            } else if (qType == QuestionType.ANSWER_64) {
                revert("unsupported question type");
            } else {
                revert("invalid question type");
            }

            bytes memory userAnswer = new bytes(answerLength);
            bytes memory correctAnswer = new bytes(answerLength);

            for (uint256 j = 0; j < answerLength; j++) {
                userAnswer[j] = answers[answerIndex + j];
                correctAnswer[j] = corrects[answerIndex + j];
            }

            bool isCorrect = keccak256(userAnswer) == keccak256(correctAnswer);

            if (isCorrect) {
                uint8 point = uint8(points[questionIndex]);
                uint8 multiplier = uint8(pointsMultiplier[questionIndex]);
                if (multiplier == 0) {
                    return 0;
                }
                score += point * multiplier;
            }

            questionIndex++;
            answerIndex += answerLength;
        }

        scoreMap[msg.sender] = score;
        return score;
    }
}
